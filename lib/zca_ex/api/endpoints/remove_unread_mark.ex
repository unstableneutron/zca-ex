defmodule ZcaEx.Api.Endpoints.RemoveUnreadMark do
  @moduledoc """
  Remove unread mark from a conversation.

  ## Notes
  - Works for both user (1:1) and group conversations
  - Marks conversation as read in the conversation list
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Remove unread mark from a conversation.

  ## Parameters
    - `thread_id` - The conversation ID (user ID for DM, group ID for group)
    - `thread_type` - `:user` for DM or `:group` for group chat (default: `:user`)
    - `session` - The authenticated session
    - `credentials` - Account credentials

  ## Returns
    - `{:ok, %{update_id: integer(), status: integer()}}` on success
    - `{:error, ZcaEx.Error.t()}` on failure
  """
  @spec remove(String.t(), :user | :group, Session.t(), Credentials.t()) ::
          {:ok, %{update_id: integer() | nil, status: integer() | nil}} | {:error, Error.t()}
  def remove(thread_id, session, credentials), do: remove(thread_id, :user, session, credentials)

  def remove(thread_id, thread_type, session, credentials) do
    with :ok <- validate_thread_id(thread_id),
         :ok <- validate_thread_type(thread_type) do
      timestamp = System.system_time(:millisecond)
      params = build_params(thread_id, thread_type, timestamp)

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
  def build_params(thread_id, thread_type, timestamp) do
    conv_data = %{"id" => thread_id, "ts" => timestamp}

    {conv_key, conv_empty_key, data_key, data_empty_key} =
      case thread_type do
        :user -> {"convsUser", "convsGroup", "convsUserData", "convsGroupData"}
        :group -> {"convsGroup", "convsUser", "convsGroupData", "convsUserData"}
      end

    inner_param = %{
      conv_key => [thread_id],
      conv_empty_key => [],
      data_key => [conv_data],
      data_empty_key => []
    }

    case Jason.encode(inner_param) do
      {:ok, json} -> %{"param" => json}
      {:error, _} -> %{"param" => "{}"}
    end
  end

  @doc false
  def build_url(session) do
    service_url = get_service_url(session)
    Url.build_for_session("#{service_url}/api/conv/removeUnreadMark", %{}, session)
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
