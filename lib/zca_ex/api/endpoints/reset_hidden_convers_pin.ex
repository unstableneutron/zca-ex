defmodule ZcaEx.Api.Endpoints.ResetHiddenConversPin do
  @moduledoc "Reset hidden conversations PIN"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Reset hidden conversations PIN.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t()) :: {:ok, :success} | {:error, Error.t()}
  def call(session, credentials) do
    case get_service_url(session) do
      {:ok, service_url} ->
        params = build_params()

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(service_url, encrypted_params, session)

            case AccountClient.get(session.uid, url, credentials.user_agent) do
              {:ok, response} ->
                case Response.parse(response, session.secret_key) do
                  {:ok, _data} -> {:ok, :success}
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

  @doc "Build URL for reset hidden convers pin endpoint with encrypted params"
  @spec build_url(String.t(), String.t(), Session.t()) :: String.t()
  def build_url(base_url, encrypted_params, session) do
    url = base_url <> "/api/hiddenconvers/reset"
    Url.build_for_session(url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, service_url} ->
        base_url = service_url <> "/api/hiddenconvers/reset"
        {:ok, Url.build_for_session(base_url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption (empty params - no imei)"
  @spec build_params() :: map()
  def build_params do
    %{}
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["conversation"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "conversation service URL not found", code: :service_not_found)}
    end
  end
end
