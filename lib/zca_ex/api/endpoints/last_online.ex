defmodule ZcaEx.Api.Endpoints.LastOnline do
  @moduledoc "Get a user's last online time"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get a user's last online time.

  ## Parameters
    - user_id: User ID (non-empty string)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{settings: %{show_online_status: boolean}, last_online: integer}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec get(String.t(), Session.t(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(user_id, _session, _credentials)
      when not is_binary(user_id) or user_id == "" do
    {:error, Error.new(:api, "user_id must be a non-empty string", code: :invalid_input)}
  end

  def get(user_id, session, credentials) do
    case get_service_url(session) do
      {:ok, service_url} ->
        params = build_params(user_id, credentials.imei)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(service_url, session, encrypted_params)

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

  @doc "Build URL for last online endpoint with encrypted params"
  @spec build_url(String.t(), Session.t(), String.t()) :: String.t()
  def build_url(service_url, session, encrypted_params) do
    base_url = service_url <> "/api/social/profile/lastOnline"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, service_url} ->
        base_url = service_url <> "/api/social/profile/lastOnline"
        {:ok, Url.build_for_session(base_url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t()) :: map()
  def build_params(user_id, imei) do
    %{uid: user_id, conv_type: 1, imei: imei}
  end

  @doc "Transform response data"
  @spec transform_response(map()) :: map()
  def transform_response(data) when is_map(data) do
    settings = data["settings"] || data[:settings] || %{}
    show_online_status = settings["show_online_status"] || settings[:show_online_status]

    %{
      settings: %{
        show_online_status: show_online_status
      },
      last_online: data["lastOnline"] || data[:lastOnline] || data["last_online"] || data[:last_online]
    }
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["profile"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "profile service URL not found", code: :invalid_input)}
    end
  end
end
