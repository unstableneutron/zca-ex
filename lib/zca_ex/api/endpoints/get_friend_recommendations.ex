defmodule ZcaEx.Api.Endpoints.GetFriendRecommendations do
  @moduledoc "Get friend recommendations and received friend requests"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get friend recommendations.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{expired_duration: integer, collapse_msg_list_config: map, recomm_items: list}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec list(Session.t(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def list(session, credentials) do
    params = build_params(credentials.imei)

    with {:ok, base_url} <- get_service_url(session),
         {:ok, encrypted_params} <- encrypt_params(session.secret_key, params) do
      url = build_url(base_url, encrypted_params, session)

      case AccountClient.get(session.uid, url, credentials.user_agent) do
        {:ok, response} ->
          case Response.parse(response, session.secret_key) do
            {:ok, data} -> {:ok, transform_response(data)}
            {:error, _} = error -> error
          end

        {:error, reason} ->
          {:error, Error.new(:network, "Request failed: #{inspect(reason)}", reason: reason)}
      end
    end
  end

  @doc "Build URL for get friend recommendations endpoint with encrypted params"
  @spec build_url(String.t(), String.t(), Session.t()) :: String.t()
  def build_url(base_url, encrypted_params, session) do
    url = base_url <> "/api/friend/recommendsv2/list"
    Url.build_for_session(url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, base_url} ->
        url = base_url <> "/api/friend/recommendsv2/list"
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
    %{
      expired_duration:
        data["expiredDuration"] || data[:expiredDuration] || data["expired_duration"] ||
          data[:expired_duration],
      collapse_msg_list_config:
        data["collapseMsgListConfig"] || data[:collapseMsgListConfig] ||
          data["collapse_msg_list_config"] || data[:collapse_msg_list_config],
      recomm_items:
        data["recommItems"] || data[:recommItems] || data["recomm_items"] || data[:recomm_items] ||
          []
    }
  end

  @spec get_service_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["friend"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "friend service URL not found", code: :service_not_found)}
    end
  end
end
