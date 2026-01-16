defmodule ZcaEx.Api.Endpoints.DisperseGroup do
  @moduledoc "Disperse (dissolve) a group"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Disperse (dissolve) a group.

  ## Parameters
    - group_id: The group ID to disperse
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(group_id, session, credentials) do
    params = build_params(group_id, credentials)

    with {:ok, encrypted_params} <- encrypt_params(session.secret_key, params),
         {:ok, service_url} <- get_service_url(session, :group) do
      url = build_url(service_url, session)
      body = build_form_body(%{params: encrypted_params})

      case AccountClient.post(session.uid, url, body, credentials.user_agent) do
        {:ok, response} ->
          Response.parse(response, session.secret_key)

        {:error, reason} ->
          {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
      end
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), Credentials.t()) :: map()
  def build_params(group_id, credentials) do
    %{
      grid: group_id,
      imei: credentials.imei
    }
  end

  @doc "Build URL for disperse group endpoint"
  @spec build_url(String.t(), Session.t()) :: String.t()
  def build_url(service_url, session) do
    base_url = service_url <> "/api/group/disperse"
    Url.build_for_session(base_url, %{}, session)
  end

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, %Error{message: "Service URL not found for #{service}", code: nil}}
    end
  end
end
