defmodule ZcaEx.Api.Endpoints.GetAllGroups do
  @moduledoc "Get all groups list"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Get all groups.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{version: String.t(), grid_ver_map: %{group_id => version}}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t()) ::
          {:ok, %{version: String.t(), grid_ver_map: map()}} | {:error, Error.t()}
  def call(session, credentials) do
    url = build_url(session)

    case AccountClient.get(session.uid, url, credentials.user_agent) do
      {:ok, response} ->
        with {:ok, data} <- Response.parse(response, session.secret_key) do
          {:ok, transform_response(data)}
        end

      {:error, reason} ->
        {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
    end
  end

  @doc "Build URL for get all groups endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session, :group_poll) <> "/api/group/getlg/v4"
    Url.build_for_session(base_url, %{}, session)
  end

  defp transform_response(data) do
    %{
      version: Map.get(data, "version") || Map.get(data, :version),
      grid_ver_map: Map.get(data, "gridVerMap") || Map.get(data, :gridVerMap) || %{}
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
