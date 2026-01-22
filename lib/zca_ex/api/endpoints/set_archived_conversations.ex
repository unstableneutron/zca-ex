defmodule ZcaEx.Api.Endpoints.SetArchivedConversations do
  @moduledoc "Archive or unarchive conversations"

  use ZcaEx.Api.Factory

  alias ZcaEx.Model.Enums
  alias ZcaEx.Error

  @type conversation_target :: %{id: String.t(), type: Enums.thread_type()}
  @type archive_response :: %{need_resync: boolean(), version: integer()}

  @doc """
  Archive or unarchive conversations.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - is_archived: true to archive, false to unarchive
    - conversations: Single target or list of targets with :id and :type

  ## Returns
    - `{:ok, archive_response()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(
          Session.t(),
          Credentials.t(),
          boolean(),
          conversation_target() | [conversation_target()]
        ) ::
          {:ok, archive_response()} | {:error, Error.t()}
  def call(session, credentials, is_archived, conversations) do
    conversations_list = normalize_conversations(conversations)

    case validate_conversations(conversations_list) do
      :ok ->
        params = build_params(is_archived, conversations_list, credentials.imei)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(session, encrypted_params)

            body = build_form_body(%{params: encrypted_params})

            case AccountClient.post(session.uid, url, body, credentials.user_agent) do
              {:ok, response} ->
                case Response.parse(response, session.secret_key) do
                  {:ok, data} -> {:ok, transform_response(data)}
                  {:error, _} = error -> error
                end

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

  @doc "Normalize conversations to list"
  @spec normalize_conversations(conversation_target() | [conversation_target()]) :: [
          conversation_target()
        ]
  def normalize_conversations(conversations) when is_list(conversations), do: conversations
  def normalize_conversations(conversation) when is_map(conversation), do: [conversation]

  @doc "Validate conversations"
  @spec validate_conversations([conversation_target()]) :: :ok | {:error, Error.t()}
  def validate_conversations([]),
    do: {:error, %Error{message: "conversations cannot be empty", code: nil}}

  def validate_conversations(conversations) do
    if Enum.all?(conversations, &valid_conversation?/1) do
      :ok
    else
      {:error,
       %Error{
         message: "each conversation must have :id (string) and :type (:user or :group)",
         code: nil
       }}
    end
  end

  defp valid_conversation?(%{id: id, type: type})
       when is_binary(id) and byte_size(id) > 0 and type in [:user, :group],
       do: true

  defp valid_conversation?(_), do: false

  @doc "Build URL for set archived conversations endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session) <> "/api/archivedchat/update"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session) <> "/api/archivedchat/update"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(boolean(), [conversation_target()], String.t()) :: map()
  def build_params(is_archived, conversations, imei) do
    ids =
      Enum.map(conversations, fn %{id: id, type: type} ->
        %{id: id, type: Enums.thread_type_value(type)}
      end)

    %{
      actionType: if(is_archived, do: 0, else: 1),
      ids: ids,
      imei: imei,
      version: :os.system_time(:millisecond)
    }
  end

  @doc "Transform response data"
  @spec transform_response(map()) :: archive_response()
  def transform_response(data) do
    %{
      need_resync: data["needResync"] == true || data["needResync"] == 1,
      version: data["version"] || 0
    }
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["label"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for label"
    end
  end
end
