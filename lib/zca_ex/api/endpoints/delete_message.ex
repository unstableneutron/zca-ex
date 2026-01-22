defmodule ZcaEx.Api.Endpoints.DeleteMessage do
  @moduledoc """
  Delete a message from a conversation.

  ## Notes
  - If message is from self and `only_me: false`, use `UndoMessage` instead
  - Cannot delete for everyone in private chats (user threads)
  """

  use ZcaEx.Api.Factory

  @type message_data :: %{
          cli_msg_id: String.t(),
          msg_id: String.t(),
          uid_from: String.t()
        }

  @type destination :: %{
          data: message_data(),
          thread_id: String.t(),
          type: :user | :group | nil
        }

  @doc """
  Delete a message.

  ## Parameters
    - `destination` - Target message info including data (cli_msg_id, msg_id, uid_from), thread_id, type
    - `only_me` - If true, delete only for self; if false, delete for everyone (default: false)
    - `session` - The authenticated session
    - `credentials` - Account credentials

  ## Returns
    - `{:ok, %{status: integer()}}` on success
    - `{:error, ZcaEx.Error.t()}` on failure
  """
  @spec call(destination(), boolean(), Session.t(), Credentials.t()) ::
          {:ok, %{status: integer()}} | {:error, ZcaEx.Error.t()}
  def call(destination, only_me \\ false, session, credentials) do
    with :ok <- validate_destination(destination) do
      thread_type = destination[:type] || destination.type || :user
      is_self = destination.data.uid_from == session.uid

      with :ok <- validate_delete(is_self, only_me, thread_type) do
        params = build_params(destination, only_me, thread_type, credentials)

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
  end

  defp validate_destination(%{
         data: %{cli_msg_id: _, msg_id: _, uid_from: _},
         thread_id: thread_id
       })
       when is_binary(thread_id) and byte_size(thread_id) > 0 do
    :ok
  end

  defp validate_destination(_) do
    {:error,
     %ZcaEx.Error{
       message:
         "Invalid destination: must have data (cli_msg_id, msg_id, uid_from) and thread_id",
       code: nil
     }}
  end

  defp validate_delete(true, false, _thread_type) do
    {:error,
     ZcaEx.Error.api(nil, "Cannot delete own message for everyone. Use undo API instead.")}
  end

  defp validate_delete(_is_self, false, :user) do
    {:error, ZcaEx.Error.api(nil, "Cannot delete for everyone in private chat")}
  end

  defp validate_delete(_is_self, _only_me, _thread_type), do: :ok

  defp build_params(destination, only_me, thread_type, credentials) do
    msg = %{
      cliMsgId: destination.data.cli_msg_id,
      globalMsgId: destination.data.msg_id,
      ownerId: destination.data.uid_from,
      destId: destination.thread_id
    }

    base_params = %{
      cliMsgId: System.system_time(:millisecond),
      msgs: [msg],
      onlyMe: if(only_me, do: 1, else: 0)
    }

    case thread_type do
      :user ->
        base_params
        |> Map.put(:toid, destination.thread_id)
        |> Map.put(:imei, credentials.imei)

      :group ->
        Map.put(base_params, :grid, destination.thread_id)
    end
  end

  defp build_url(:user, session) do
    base = get_in(session.zpw_service_map, ["chat"]) || []
    service_url = List.first(base) || "https://tt-chat3-wpa.chat.zalo.me"
    Url.build_for_session("#{service_url}/api/message/delete", %{}, session)
  end

  defp build_url(:group, session) do
    base = get_in(session.zpw_service_map, ["group"]) || []
    service_url = List.first(base) || "https://tt-group-wpa.chat.zalo.me"
    Url.build_for_session("#{service_url}/api/group/deletemsg", %{}, session)
  end

  defp transform_response({:ok, %{"status" => status}}) do
    {:ok, %{status: status}}
  end

  defp transform_response({:ok, data}) when is_map(data) do
    {:ok, %{status: data["status"] || 0}}
  end

  defp transform_response({:error, _} = error), do: error
end
