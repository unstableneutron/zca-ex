defmodule ZcaEx.Api.Endpoints.GetGroupInfo do
  @moduledoc "Get group information"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Get group info by ID(s).

  ## Parameters
    - group_ids: Single group ID or list of group IDs
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{gridInfoMap: map(), unchangedsGroup: list(), removedsGroup: list()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t() | [String.t()], Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(group_ids, session, credentials) when is_binary(group_ids) do
    call([group_ids], session, credentials)
  end

  def call(group_ids, session, credentials) when is_list(group_ids) do
    grid_ver_map = build_grid_ver_map(group_ids)

    params = %{
      gridVerMap: Jason.encode!(grid_ver_map)
    }

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session)

        body = build_form_body(%{params: encrypted_params})

        case AccountClient.post(session.uid, url, body, credentials.user_agent) do
          {:ok, response} ->
            Response.parse(response, session.secret_key)

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL for get group info endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/getmg-v2"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build gridVerMap from group IDs (each ID maps to version 0)"
  @spec build_grid_ver_map([String.t()]) :: map()
  def build_grid_ver_map(group_ids) do
    Enum.reduce(group_ids, %{}, fn id, acc ->
      Map.put(acc, id, 0)
    end)
  end

  @doc "Build params for encryption"
  @spec build_params([String.t()]) :: map()
  def build_params(group_ids) do
    %{
      gridVerMap: Jason.encode!(build_grid_ver_map(group_ids))
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
