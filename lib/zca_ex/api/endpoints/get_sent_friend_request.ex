defmodule ZcaEx.Api.Endpoints.GetSentFriendRequest do
  @moduledoc "Get list of sent friend requests"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get list of sent friend requests.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, map()}` - Map of userId -> user info on success
    - `{:error, Error.t()}` on failure

  ## Notes
    - May return error code 112 if no friend requests exist
  """
  @spec list(Session.t(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def list(session, credentials) do
    case get_service_url(session) do
      {:ok, base_url} ->
        params = build_params(credentials.imei)

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

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL for get sent friend request endpoint with encrypted params"
  @spec build_url(String.t(), Session.t(), String.t()) :: String.t()
  def build_url(base_url, session, encrypted_params) do
    url = base_url <> "/api/friend/requested/list"
    Url.build_for_session(url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, base_url} ->
        url = base_url <> "/api/friend/requested/list"
        {:ok, Url.build_for_session(url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t()) :: map()
  def build_params(imei) do
    %{imei: imei}
  end

  @doc "Transform response data"
  @spec transform_response(map()) :: map()
  def transform_response(data) when is_map(data) do
    data
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["friend"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "friend service URL not found", code: :service_not_found)}
    end
  end
end
