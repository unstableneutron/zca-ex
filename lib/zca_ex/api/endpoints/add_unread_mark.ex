defmodule ZcaEx.Api.Endpoints.AddUnreadMark do
  @moduledoc """
  Add unread mark to a conversation.

  ## Notes
  - Works for both user (1:1) and group conversations
  - Marks conversation as unread in the conversation list
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Add unread mark to a conversation.

  ## Parameters
    - `thread_id` - The conversation ID (user ID for DM, group ID for group)
    - `thread_type` - `:user` for DM or `:group` for group chat (default: `:user`)
    - `session` - The authenticated session
    - `credentials` - Account credentials

  ## Returns
    - `{:ok, %{update_id: integer(), status: integer()}}` on success
    - `{:error, ZcaEx.Error.t()}` on failure
  """
  @spec add(String.t(), :user | :group, Session.t(), Credentials.t()) ::
          {:ok, %{update_id: integer() | nil, status: integer() | nil}} | {:error, Error.t()}
  def add(thread_id, session, credentials), do: add(thread_id, :user, session, credentials)

  def add(thread_id, thread_type, session, credentials) do
    with :ok <- validate_thread_id(thread_id),
         :ok <- validate_thread_type(thread_type) do
      timestamp = System.system_time(:millisecond)
      params = build_params(thread_id, thread_type, timestamp, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
            {:ok, resp} ->
              Response.parse(resp, session.secret_key)
              |> transform_response()

            {:error, reason} ->
              {:error, Error.new(:network, "Request failed: #{inspect(reason)}", reason: reason)}
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
    {:error, Error.new(:api, "thread_id must be a non-empty string", code: :invalid_input)}
  end

  defp validate_thread_type(type) when type in [:user, :group], do: :ok

  defp validate_thread_type(_) do
    {:error, Error.new(:api, "thread_type must be :user or :group", code: :invalid_input)}
  end

  @doc false
  def build_params(thread_id, thread_type, timestamp, credentials) do
    timestamp_str = Integer.to_string(timestamp)

    conv_entry = %{
      "id" => thread_id,
      "cliMsgId" => timestamp_str,
      "fromUid" => "0",
      "ts" => timestamp
    }

    {user_key, group_key} =
      case thread_type do
        :user -> {"convsUser", "convsGroup"}
        :group -> {"convsGroup", "convsUser"}
      end

    inner_param = %{
      user_key => [conv_entry],
      group_key => [],
      "imei" => credentials.imei
    }

    case Jason.encode(inner_param) do
      {:ok, json} -> %{"param" => json}
      {:error, _} -> %{"param" => "{}"}
    end
  end

  @doc false
  def build_url(session) do
    service_url = get_service_url(session)
    Url.build_for_session("#{service_url}/api/conv/addUnreadMark", %{}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["conversation"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "conversation service URL not found"
    end
  end

  defp transform_response({:ok, data}) when is_map(data) do
    {:ok,
     %{
       update_id: data["updateId"] || data[:updateId],
       status: data["status"] || data[:status]
     }}
  end

  defp transform_response({:ok, data}) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed} -> transform_response({:ok, parsed})
      {:error, _} -> {:ok, %{update_id: nil, status: nil}}
    end
  end

  defp transform_response({:error, _} = error), do: error
end
