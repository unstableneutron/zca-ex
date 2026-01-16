defmodule ZcaEx.Api.Endpoints.GetPinConversations do
  @moduledoc "Get list of pinned conversations"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type pin_response :: %{
          conversations: [String.t()],
          version: integer()
        }

  @doc """
  Get pinned conversations.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{conversations: [String.t()], version: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t()) :: {:ok, pin_response()} | {:error, Error.t()}
  def call(session, credentials) do
    params = build_params(credentials.imei)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
          {:ok, response} ->
            with {:ok, data} <- Response.parse(response, session.secret_key) do
              {:ok, transform_response(data)}
            end

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL for get pin conversations endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :conversation) <> "/api/pinconvers/list"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :conversation) <> "/api/pinconvers/list"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t()) :: map()
  def build_params(imei) do
    %{imei: imei}
  end

  @doc "Transform API response to structured format"
  @spec transform_response(map()) :: pin_response()
  def transform_response(data) do
    %{
      conversations: Map.get(data, "conversations") || Map.get(data, :conversations) || [],
      version: Map.get(data, "version") || Map.get(data, :version) || 0
    }
  end

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
