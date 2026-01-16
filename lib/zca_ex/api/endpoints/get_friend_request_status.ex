defmodule ZcaEx.Api.Endpoints.GetFriendRequestStatus do
  @moduledoc "Get friend request status with a user"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get friend request status with a specific user.

  ## Parameters
    - friend_id: The user ID to check status with
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, map()}` - Status info including addFriendPrivacy, isSeenFriendReq, is_friend, is_requested, is_requesting
    - `{:error, Error.t()}` on failure
  """
  @spec get(String.t(), Session.t(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(friend_id, session, credentials) do
    with :ok <- validate_friend_id(friend_id),
         {:ok, base_url} <- get_service_url(session) do
      params = build_params(friend_id, credentials.imei)

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

  @doc "Build URL for get friend request status endpoint with encrypted params"
  @spec build_url(String.t(), Session.t(), String.t()) :: String.t()
  def build_url(base_url, session, encrypted_params) do
    url = base_url <> "/api/friend/reqstatus"
    Url.build_for_session(url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, base_url} ->
        url = base_url <> "/api/friend/reqstatus"
        {:ok, Url.build_for_session(url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t()) :: map()
  def build_params(friend_id, imei) do
    %{fid: friend_id, imei: imei}
  end

  @doc "Transform response data"
  @spec transform_response(map()) :: map()
  def transform_response(data) when is_map(data) do
    data
  end

  defp validate_friend_id(friend_id) when is_binary(friend_id) and byte_size(friend_id) > 0 do
    :ok
  end

  defp validate_friend_id(_) do
    {:error, Error.new(:api, "friend_id must be a non-empty string", code: :invalid_input)}
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["friend"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "friend service URL not found", code: :invalid_input)}
    end
  end
end
