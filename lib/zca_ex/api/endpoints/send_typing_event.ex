defmodule ZcaEx.Api.Endpoints.SendTypingEvent do
  @moduledoc "Send typing indicator"

  use ZcaEx.Api.Factory

  alias ZcaEx.Model.Enums

  @doc """
  Send typing event to a user or group.

  ## Parameters
    - `thread_id` - The ID of the user or group
    - `thread_type` - Either `:user` or `:group`
    - `session` - The authenticated session
    - `credentials` - Account credentials
    - `opts` - Optional parameters:
      - `:dest_type` - Destination type for user threads (default: `:user`)

  ## Returns
    - `:ok` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), Enums.thread_type(), Session.t(), Credentials.t(), keyword()) ::
          :ok | {:error, ZcaEx.Error.t()}
  def call(thread_id, thread_type, session, credentials, opts \\ [])

  def call(nil, _thread_type, _session, _credentials, _opts) do
    {:error, %ZcaEx.Error{message: "Missing thread_id", code: nil}}
  end

  def call("", _thread_type, _session, _credentials, _opts) do
    {:error, %ZcaEx.Error{message: "Missing thread_id", code: nil}}
  end

  def call(thread_id, thread_type, session, credentials, opts) do
    dest_type = Keyword.get(opts, :dest_type, :user)

    params = build_params(thread_id, thread_type, credentials.imei, dest_type)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(thread_type, session)
        body = build_form_body(%{params: encrypted_params})

        case AccountClient.post(credentials.imei, url, body, credentials.user_agent) do
          {:ok, resp} ->
            case Response.parse(resp, session.secret_key) do
              {:ok, _data} -> :ok
              error -> error
            end

          {:error, reason} ->
            {:error, %ZcaEx.Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  defp build_params(thread_id, :user, imei, dest_type) do
    %{
      toid: thread_id,
      destType: Enums.dest_type_value(dest_type),
      imei: imei
    }
  end

  defp build_params(thread_id, :group, imei, _dest_type) do
    %{
      grid: thread_id,
      imei: imei
    }
  end

  defp build_url(:user, session) do
    base = get_in(session.zpw_service_map, ["chat"]) || []
    service_url = List.first(base) || "https://chat.zalo.me"
    Url.build_for_session("#{service_url}/api/message/typing", %{}, session)
  end

  defp build_url(:group, session) do
    base = get_in(session.zpw_service_map, ["group"]) || []
    service_url = List.first(base) || "https://groupchat.zalo.me"
    Url.build_for_session("#{service_url}/api/group/typing", %{}, session)
  end
end
