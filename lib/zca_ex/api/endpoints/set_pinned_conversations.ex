defmodule ZcaEx.Api.Endpoints.SetPinnedConversations do
  @moduledoc "Pin or unpin conversations"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Pin or unpin conversations.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - pinned: true to pin, false to unpin
    - thread_ids: Single thread ID or list of thread IDs
    - thread_type: :user or :group (default: :user)

  ## Returns
    - `{:ok, %{}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), boolean(), String.t() | [String.t()], :user | :group) ::
          {:ok, map()} | {:error, Error.t()}
  def call(session, credentials, pinned, thread_ids, thread_type \\ :user) do
    thread_ids = normalize_thread_ids(thread_ids)

    case validate_thread_ids(thread_ids) do
      :ok ->
        conversations = format_conversations(thread_ids, thread_type)
        params = build_params(pinned, conversations)

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

  @doc "Build URL for set pinned conversations endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session, :conversation) <> "/api/pinconvers/updatev2"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    build_url(session)
  end

  @doc "Build params for encryption"
  @spec build_params(boolean(), [String.t()]) :: map()
  def build_params(pinned, conversations) do
    %{
      actionType: if(pinned, do: 1, else: 2),
      conversations: conversations
    }
  end

  @doc "Format thread IDs as conversation identifiers"
  @spec format_conversations([String.t()], :user | :group) :: [String.t()]
  def format_conversations(thread_ids, :user) do
    Enum.map(thread_ids, &"u#{&1}")
  end

  def format_conversations(thread_ids, :group) do
    Enum.map(thread_ids, &"g#{&1}")
  end

  @doc "Normalize thread_ids to list"
  @spec normalize_thread_ids(String.t() | [String.t()]) :: [String.t()]
  def normalize_thread_ids(thread_id) when is_binary(thread_id), do: [thread_id]
  def normalize_thread_ids(thread_ids) when is_list(thread_ids), do: thread_ids

  @spec validate_thread_ids([String.t()]) :: :ok | {:error, Error.t()}
  defp validate_thread_ids([]),
    do: {:error, %Error{message: "thread_ids cannot be empty", code: nil}}

  defp validate_thread_ids(_), do: :ok

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
