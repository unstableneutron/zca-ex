defmodule ZcaEx.Api.Endpoints.GetArchivedChatList do
  @moduledoc "Get list of archived conversations."

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type archived_response :: %{
          items: [map()],
          version: integer()
        }

  @doc """
  Get archived chat list.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{items: list(), version: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t()) :: {:ok, archived_response()} | {:error, Error.t()}
  def call(session, credentials) do
    with {:ok, encrypted_params} <- encrypt_params(session.secret_key, build_params(credentials)),
         url <- build_url(session, encrypted_params) do
      case AccountClient.get(session.uid, url, credentials.user_agent) do
        {:ok, response} ->
          with {:ok, data} <- Response.parse(response, session.secret_key) do
            {:ok, transform_response(data)}
          end

        {:error, reason} ->
          {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
      end
    end
  end

  @doc "Build params for archived chat list request"
  @spec build_params(Credentials.t()) :: map()
  def build_params(credentials) do
    %{
      version: 1,
      imei: credentials.imei
    }
  end

  @doc "Build base URL for archived chat list endpoint"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    get_service_url(session, :label) <> "/api/archivedchat/list"
  end

  @doc "Build full URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = build_base_url(session)
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Transform API response to structured format"
  @spec transform_response(map()) :: archived_response()
  def transform_response(data) do
    %{
      items: Map.get(data, "items") || Map.get(data, :items) || [],
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
