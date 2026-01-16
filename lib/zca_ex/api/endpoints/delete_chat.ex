defmodule ZcaEx.Api.Endpoints.DeleteChat do
  @moduledoc """
  Delete a conversation (chat thread).

  ## Notes
  - Works for both user (1:1) and group conversations
  - Always deletes only for the current user (onlyMe: 1)
  """

  use ZcaEx.Api.Factory

  @type last_message :: %{
          owner_id: String.t(),
          cli_msg_id: String.t(),
          global_msg_id: String.t()
        }

  @doc """
  Delete a conversation.

  ## Parameters
    - `session` - The authenticated session
    - `credentials` - Account credentials
    - `last_message` - The last message in the conversation (owner_id, cli_msg_id, global_msg_id)
    - `thread_id` - The conversation ID (user ID for DM, group ID for group)
    - `thread_type` - `:user` for DM or `:group` for group chat (default: `:user`)

  ## Returns
    - `{:ok, %{status: integer()}}` on success
    - `{:error, ZcaEx.Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), last_message(), String.t(), :user | :group) ::
          {:ok, %{status: integer()}} | {:error, ZcaEx.Error.t()}
  def call(session, credentials, last_message, thread_id, thread_type \\ :user) do
    with :ok <- validate_thread_id(thread_id),
         :ok <- validate_last_message(last_message) do
      params = build_params(last_message, thread_id, thread_type, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(thread_type, session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
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
  end

  defp validate_thread_id(thread_id) when is_binary(thread_id) and byte_size(thread_id) > 0 do
    :ok
  end

  defp validate_thread_id(_) do
    {:error, %ZcaEx.Error{message: "Invalid thread_id: must be a non-empty string", code: nil}}
  end

  defp validate_last_message(%{owner_id: owner_id, cli_msg_id: cli_msg_id, global_msg_id: global_msg_id})
       when is_binary(owner_id) and is_binary(cli_msg_id) and is_binary(global_msg_id) do
    :ok
  end

  defp validate_last_message(_) do
    {:error,
     %ZcaEx.Error{
       message: "Invalid last_message: must have owner_id, cli_msg_id, and global_msg_id as strings",
       code: nil
     }}
  end

  @doc false
  def build_params(last_message, thread_id, thread_type, credentials) do
    conver = %{
      ownerId: last_message.owner_id,
      cliMsgId: last_message.cli_msg_id,
      globalMsgId: last_message.global_msg_id
    }

    base_params = %{
      cliMsgId: System.system_time(:millisecond),
      conver: conver,
      onlyMe: 1
    }

    case thread_type do
      :user ->
        base_params
        |> Map.put(:toid, thread_id)
        |> Map.put(:imei, credentials.imei)

      :group ->
        Map.put(base_params, :grid, thread_id)
    end
  end

  @doc false
  def build_url(:user, session) do
    service_url = get_service_url(session, "chat")
    Url.build_for_session("#{service_url}/api/message/deleteconver", %{}, session)
  end

  def build_url(:group, session) do
    service_url = get_service_url(session, "group")
    Url.build_for_session("#{service_url}/api/group/deleteconver", %{}, session)
  end

  defp get_service_url(session, service_key) do
    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service_key}"
    end
  end

  defp transform_response({:ok, %{"status" => status}}) do
    {:ok, %{status: status}}
  end

  defp transform_response({:ok, data}) when is_map(data) do
    {:ok, %{status: data["status"] || 0}}
  end

  defp transform_response({:error, _} = error), do: error
end
