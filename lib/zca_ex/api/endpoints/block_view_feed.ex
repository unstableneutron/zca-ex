defmodule ZcaEx.Api.Endpoints.BlockViewFeed do
  @moduledoc "Block or unblock a friend's feed"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Block or unblock a friend's feed.

  ## Parameters
    - user_id: User ID (non-empty string)
    - block?: Whether to block (true) or unblock (false) the feed
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, map() | String.t()}` on success (usually empty string "")
    - `{:error, Error.t()}` on failure
  """
  @spec set(String.t(), boolean(), Session.t(), Credentials.t()) ::
          {:ok, map() | String.t()} | {:error, Error.t()}
  def set(user_id, _block?, _session, _credentials)
      when not is_binary(user_id) or user_id == "" do
    {:error, Error.new(:api, "user_id must be a non-empty string", code: :invalid_input)}
  end

  def set(_user_id, block?, _session, _credentials) when not is_boolean(block?) do
    {:error, Error.new(:api, "block? must be a boolean", code: :invalid_input)}
  end

  def set(user_id, block?, session, credentials) do
    case get_service_url(session) do
      {:ok, service_url} ->
        params = build_params(user_id, block?, credentials.imei)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(service_url, session)
            body = build_form_body(%{params: encrypted_params})

            case AccountClient.post(session.uid, url, body, credentials.user_agent) do
              {:ok, response} ->
                case Response.parse(response, session.secret_key) do
                  {:ok, data} -> {:ok, data}
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

  @doc "Build URL for block view feed endpoint"
  @spec build_url(String.t(), Session.t()) :: String.t()
  def build_url(service_url, session) do
    base_url = service_url <> "/api/friend/feed/block"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build base URL (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, service_url} ->
        {:ok, build_url(service_url, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), boolean(), String.t()) :: map()
  def build_params(user_id, block?, imei) do
    %{fid: user_id, isBlockFeed: if(block?, do: 1, else: 0), imei: imei}
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["friend"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "friend service URL not found", code: :service_not_found)}
    end
  end
end
