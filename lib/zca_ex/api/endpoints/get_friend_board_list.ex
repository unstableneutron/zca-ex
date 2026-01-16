defmodule ZcaEx.Api.Endpoints.GetFriendBoardList do
  @moduledoc "Get friend board list for a conversation"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get friend board list for a conversation.

  ## Parameters
    - conversation_id: The conversation ID
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{data: list, version: integer}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec get(String.t(), Session.t(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(conversation_id, session, credentials) do
    with :ok <- validate_conversation_id(conversation_id),
         {:ok, base_url} <- get_service_url(session) do
      params = build_params(conversation_id, credentials.imei)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(base_url, session, encrypted_params)

          case AccountClient.get(session.uid, url, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, data} -> {:ok, transform_response(data)}
                {:error, _} = error -> error
              end

            {:error, reason} ->
              {:error, Error.new(:network, "Request failed: #{inspect(reason)}", reason: reason)}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "Build URL for get friend board list endpoint with encrypted params"
  @spec build_url(String.t(), Session.t(), String.t()) :: String.t()
  def build_url(base_url, session, encrypted_params) do
    url = base_url <> "/api/friendboard/list"
    Url.build_for_session(url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, base_url} ->
        url = base_url <> "/api/friendboard/list"
        {:ok, Url.build_for_session(url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t()) :: map()
  def build_params(conversation_id, imei) do
    %{
      conversationId: conversation_id,
      version: 0,
      imei: imei
    }
  end

  @doc "Transform response data"
  @spec transform_response(map()) :: map()
  def transform_response(data) when is_map(data) do
    %{
      data: data["data"] || data[:data] || [],
      version: data["version"] || data[:version] || 0
    }
  end

  defp validate_conversation_id(conversation_id)
       when is_binary(conversation_id) and byte_size(conversation_id) > 0 do
    :ok
  end

  defp validate_conversation_id(_) do
    {:error, Error.new(:api, "conversation_id must be a non-empty string", code: :invalid_input)}
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["friend_board"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "friend_board service URL not found", code: :service_not_found)}
    end
  end
end
