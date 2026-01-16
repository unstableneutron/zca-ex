defmodule ZcaEx.Api.Endpoints.UpdateActiveStatus do
  @moduledoc "Update account active status (online/offline)"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Update active status.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - active: true for online, false for offline

  ## Returns
    - `{:ok, %{status: boolean()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), boolean()) ::
          {:ok, %{status: boolean()}} | {:error, Error.t()}
  def call(session, credentials, active) when is_boolean(active) do
    params = build_params(active, credentials.imei)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, active, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
          {:ok, response} ->
            case Response.parse(response, session.secret_key) do
              {:ok, data} -> {:ok, transform_response(data)}
              {:error, _} = error -> error
            end

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @spec build_url(Session.t(), boolean(), String.t()) :: String.t()
  def build_url(session, active, encrypted_params) do
    path = if active, do: "/api/social/profile/ping", else: "/api/social/profile/deactive"
    base_url = get_service_url(session, :profile) <> path
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t(), boolean()) :: String.t()
  def build_base_url(session, active) do
    path = if active, do: "/api/social/profile/ping", else: "/api/social/profile/deactive"
    base_url = get_service_url(session, :profile) <> path
    Url.build_for_session(base_url, %{}, session)
  end

  @spec build_params(boolean(), String.t()) :: map()
  def build_params(active, imei) do
    %{
      status: if(active, do: 1, else: 0),
      imei: imei
    }
  end

  defp transform_response(data) do
    status = data["status"] || data[:status]
    %{status: status == true || status == 1}
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
