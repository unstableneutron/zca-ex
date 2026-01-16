defmodule ZcaEx.Api.Endpoints.RemoveReminder do
  @moduledoc "Remove a reminder from a user or group thread"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type thread_type :: :user | :group

  @doc """
  Remove a reminder from a thread.

  ## Parameters
    - thread_id: User ID or Group ID
    - reminder_id: The reminder/topic ID to remove
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Options
      - `:thread_type` - `:user` (default) or `:group`

  ## Returns
    - `{:ok, map()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), String.t(), Session.t(), Credentials.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(thread_id, reminder_id, session, credentials, opts \\ []) do
    thread_type = Keyword.get(opts, :thread_type, :user)

    with :ok <- validate_thread_type(thread_type) do
      params = build_params(thread_id, reminder_id, credentials, opts)

      case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, thread_type)
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

  @doc "Validate thread_type"
  @spec validate_thread_type(term()) :: :ok | {:error, Error.t()}
  def validate_thread_type(:user), do: :ok
  def validate_thread_type(:group), do: :ok
  def validate_thread_type(_), do: {:error, %Error{message: "thread_type must be :user or :group", code: nil}}

  @doc "Build URL for remove reminder endpoint"
  @spec build_url(Session.t(), thread_type()) :: String.t()
  def build_url(session, thread_type) do
    path =
      case thread_type do
        :user -> "/api/board/oneone/remove"
        :group -> "/api/board/topic/remove"
      end

    base_url = get_service_url(session, :group_board) <> path
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t(), Credentials.t(), keyword()) :: map()
  def build_params(thread_id, reminder_id, credentials, opts) do
    thread_type = Keyword.get(opts, :thread_type, :user)

    case thread_type do
      :user ->
        %{
          uid: thread_id,
          reminderId: reminder_id
        }

      :group ->
        %{
          grid: thread_id,
          topicId: reminder_id,
          imei: credentials.imei
        }
    end
  end

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
