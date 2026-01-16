defmodule ZcaEx.Api.Endpoints.UpdateAutoDeleteChat do
  @moduledoc """
  Update auto-delete settings for a conversation.

  ## TTL Options
    - `:no_delete` - Messages are never deleted (0)
    - `:one_day` - Messages deleted after 1 day (86,400,000 ms)
    - `:seven_days` - Messages deleted after 7 days (604,800,000 ms)
    - `:fourteen_days` - Messages deleted after 14 days (1,209,600,000 ms)
    - Any non-negative integer for custom TTL in milliseconds
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @ttl_no_delete 0
  @ttl_one_day 86_400_000
  @ttl_seven_days 604_800_000
  @ttl_fourteen_days 1_209_600_000

  @type chat_ttl :: :no_delete | :one_day | :seven_days | :fourteen_days | non_neg_integer()

  @doc """
  Update auto-delete settings for a conversation.

  ## Parameters
    - `ttl` - Time-to-live for messages (atom or milliseconds)
    - `thread_id` - The conversation thread ID
    - `thread_type` - `:user` for direct messages, `:group` for group chats
    - `session` - Authenticated session
    - `credentials` - Account credentials

  ## Returns
    - `{:ok, map()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), chat_ttl(), String.t(), :user | :group) ::
          {:ok, map()} | {:error, Error.t()}
  def call(session, credentials, ttl, thread_id, thread_type \\ :user) do
    with :ok <- validate_thread_id(thread_id),
         {:ok, ttl_value} <- ttl_to_value(ttl),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(ttl_value, thread_id, thread_type, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
            {:ok, response} ->
              Response.parse(response, session.secret_key)

            {:error, reason} ->
              {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "Build params for encryption"
  @spec build_params(non_neg_integer(), String.t(), :user | :group, Credentials.t()) :: map()
  def build_params(ttl_value, thread_id, thread_type, credentials) do
    %{
      threadId: thread_id,
      isGroup: thread_type_to_int(thread_type),
      ttl: ttl_value,
      clientLang: credentials.language
    }
  end

  @doc "Build base URL for update auto-delete endpoint"
  @spec build_base_url(String.t()) :: String.t()
  def build_base_url(service_url) do
    service_url <> "/api/conv/autodelete/updateConvers"
  end

  @doc "Build full URL with session params"
  @spec build_url(String.t(), Session.t()) :: String.t()
  def build_url(service_url, session) do
    base_url = build_base_url(service_url)
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Convert TTL atom to milliseconds value"
  @spec ttl_to_value(chat_ttl()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def ttl_to_value(:no_delete), do: {:ok, @ttl_no_delete}
  def ttl_to_value(:one_day), do: {:ok, @ttl_one_day}
  def ttl_to_value(:seven_days), do: {:ok, @ttl_seven_days}
  def ttl_to_value(:fourteen_days), do: {:ok, @ttl_fourteen_days}

  def ttl_to_value(value) when is_integer(value) and value >= 0 do
    {:ok, value}
  end

  def ttl_to_value(invalid) do
    {:error,
     %Error{
       message:
         "Invalid TTL: #{inspect(invalid)}. Must be :no_delete, :one_day, :seven_days, :fourteen_days, or non-negative integer",
       code: nil
     }}
  end

  @doc "Convert thread type to isGroup integer"
  @spec thread_type_to_int(:user | :group) :: 0 | 1
  def thread_type_to_int(:group), do: 1
  def thread_type_to_int(_), do: 0

  defp validate_thread_id(thread_id) when is_binary(thread_id) and byte_size(thread_id) > 0 do
    :ok
  end

  defp validate_thread_id(_) do
    {:error, %Error{message: "Invalid thread_id: must be a non-empty string", code: nil}}
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["conversation"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, %Error{message: "Service URL not found for conversation", code: nil}}
    end
  end
end
