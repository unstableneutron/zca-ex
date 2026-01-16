defmodule ZcaEx.Api.Endpoints.UndoMessage do
  @moduledoc "Undo (recall) a sent message"

  use ZcaEx.Api.Factory

  alias ZcaEx.Model.Enums

  @type undo_payload :: %{
          required(:msg_id) => String.t() | integer(),
          required(:cli_msg_id) => String.t() | integer()
        }

  @doc """
  Undo (recall) a sent message.

  ## Parameters
    - `payload` - Map with msg_id and cli_msg_id of the message to undo
    - `thread_id` - The ID of the user or group thread
    - `thread_type` - Either `:user` or `:group` (defaults to `:user`)
    - `session` - The authenticated session
    - `credentials` - Account credentials

  ## Returns
    - `{:ok, %{status: integer}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(undo_payload(), String.t(), Enums.thread_type(), Session.t(), Credentials.t()) ::
          {:ok, %{status: integer()}} | {:error, ZcaEx.Error.t()}
  def call(payload, thread_id, thread_type \\ :user, session, credentials) do
    params =
      %{
        msgId: payload.msg_id,
        clientId: System.system_time(:millisecond),
        cliMsgIdUndo: payload.cli_msg_id
      }
      |> add_thread_params(thread_id, thread_type, credentials)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(thread_type, session)
        body = build_form_body(%{params: encrypted_params})

        case AccountClient.post(credentials.imei, url, body, credentials.user_agent) do
          {:ok, resp} ->
            Response.parse(resp, session.secret_key)
            |> transform_response()

          {:error, reason} ->
            {:error, %ZcaEx.Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  defp add_thread_params(params, thread_id, :user, _credentials) do
    Map.put(params, :toid, thread_id)
  end

  defp add_thread_params(params, thread_id, :group, credentials) do
    params
    |> Map.put(:grid, thread_id)
    |> Map.put(:visibility, 0)
    |> Map.put(:imei, credentials.imei)
  end

  defp build_url(:user, session) do
    base = get_in(session.zpw_service_map, ["chat"]) || []
    service_url = List.first(base) || "https://chat.zalo.me"
    Url.build_for_session("#{service_url}/api/message/undo", %{}, session)
  end

  defp build_url(:group, session) do
    base = get_in(session.zpw_service_map, ["group"]) || []
    service_url = List.first(base) || "https://groupchat.zalo.me"
    Url.build_for_session("#{service_url}/api/group/undomsg", %{}, session)
  end

  defp transform_response({:ok, %{"status" => status}}) do
    {:ok, %{status: status}}
  end

  defp transform_response({:ok, data}) do
    {:ok, %{status: Map.get(data, "status", 0)}}
  end

  defp transform_response(error), do: error
end
