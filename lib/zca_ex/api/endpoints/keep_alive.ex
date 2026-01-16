defmodule ZcaEx.Api.Endpoints.KeepAlive do
  @moduledoc "Keep connection alive to the chat service"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Send a keep-alive request to the chat service.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{config_version: integer}}` on success
    - `{:error, Error.t()}` on failure

  ## Notes
    - Response is NOT encrypted
    - JS API has typo "config_vesion", normalized to "config_version" here
  """
  @spec call(Session.t(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def call(session, credentials) do
    case get_service_url(session) do
      {:ok, service_url} ->
        params = build_params(credentials.imei)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(service_url, session, encrypted_params)

            case AccountClient.get(session.uid, url, credentials.user_agent) do
              {:ok, response} ->
                case Response.parse_unencrypted(response) do
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

  @doc "Build URL for keep alive endpoint with encrypted params"
  @spec build_url(String.t(), Session.t(), String.t()) :: String.t()
  def build_url(service_url, session, encrypted_params) do
    base_url = service_url <> "/keepalive"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, service_url} ->
        base_url = service_url <> "/keepalive"
        {:ok, Url.build_for_session(base_url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t()) :: map()
  def build_params(imei) do
    %{imei: imei}
  end

  @doc "Transform response data (normalizes JS typo 'config_vesion' to 'config_version')"
  @spec transform_response(map()) :: map()
  def transform_response(data) when is_map(data) do
    config_version =
      Map.get(data, "config_vesion") ||
        Map.get(data, :config_vesion) ||
        Map.get(data, "config_version") ||
        Map.get(data, :config_version) ||
        0

    %{config_version: coerce_to_integer(config_version)}
  end

  defp coerce_to_integer(val) when is_integer(val), do: val
  defp coerce_to_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> 0
    end
  end
  defp coerce_to_integer(_), do: 0

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["chat"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "chat service URL not found", code: :service_not_found)}
    end
  end
end
