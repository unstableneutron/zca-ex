defmodule ZcaEx.Api.Endpoints.SetHiddenConversations do
  @moduledoc """
  Hide or unhide conversations.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Hide or unhide conversations.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - hidden: true to hide, false to unhide
    - thread_ids: Single thread ID or list of thread IDs
    - thread_type: :user or :group (default: :user)

  ## Returns
    - `{:ok, map()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), boolean(), String.t() | [String.t()], :user | :group) ::
          {:ok, map()} | {:error, Error.t()}
  def call(session, credentials, hidden, thread_ids, thread_type \\ :user)

  def call(_session, _credentials, _hidden, [], _thread_type) do
    {:error, %Error{message: "Thread IDs cannot be empty", code: nil}}
  end

  def call(_session, _credentials, _hidden, "", _thread_type) do
    {:error, %Error{message: "Thread ID cannot be empty", code: nil}}
  end

  def call(session, credentials, hidden, thread_id, thread_type) when is_binary(thread_id) do
    call(session, credentials, hidden, [thread_id], thread_type)
  end

  def call(session, credentials, hidden, thread_ids, thread_type) when is_list(thread_ids) do
    threads = format_threads(thread_ids, thread_type)

    case build_params(threads, hidden, credentials.imei) do
      {:ok, params} ->
        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(session)
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

      {:error, _} = error ->
        error
    end
  end

  @doc "Format threads for the API request"
  @spec format_threads([String.t()], :user | :group) :: [map()]
  def format_threads(thread_ids, thread_type) do
    is_group = if thread_type == :group, do: 1, else: 0

    Enum.map(thread_ids, fn thread_id ->
      %{thread_id: thread_id, is_group: is_group}
    end)
  end

  @doc "Build params for encryption"
  @spec build_params([map()], boolean(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def build_params(threads, hidden, imei) do
    case Jason.encode(threads) do
      {:ok, threads_json} ->
        params =
          if hidden do
            %{
              add_threads: threads_json,
              del_threads: "[]",
              imei: imei
            }
          else
            %{
              add_threads: "[]",
              del_threads: threads_json,
              imei: imei
            }
          end

        {:ok, params}

      {:error, reason} ->
        {:error, %Error{message: "Failed to encode threads: #{inspect(reason)}", code: nil}}
    end
  end

  @doc "Build URL for set hidden conversations endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session) <> "/api/hiddenconvers/add-remove"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build base URL without session params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    get_service_url(session) <> "/api/hiddenconvers/add-remove"
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["conversation"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for conversation"
    end
  end
end
