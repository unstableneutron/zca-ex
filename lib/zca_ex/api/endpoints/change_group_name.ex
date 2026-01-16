defmodule ZcaEx.Api.Endpoints.ChangeGroupName do
  @moduledoc "Change group name"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Change a group's name.

  ## Parameters
    - name: New group name (if empty, uses timestamp)
    - group_id: Group ID to rename
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{status: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(name, group_id, session, credentials) do
    params = build_params(name, group_id, credentials)

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

  @doc "Build URL for change group name endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/updateinfo"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t(), Credentials.t()) :: map()
  def build_params(name, group_id, credentials) do
    effective_name =
      if name == "" do
        Integer.to_string(System.system_time(:millisecond))
      else
        name
      end

    %{
      grid: group_id,
      gname: effective_name,
      imei: credentials.imei
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
