defmodule ZcaEx.Api.Endpoints.LeaveGroup do
  @moduledoc "Leave a group"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Leave a group.

  ## Parameters
    - group_id: Group ID to leave
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Options
      - silent: Whether to leave silently (default: false)

  ## Returns
    - `{:ok, %{member_error: list()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), Session.t(), Credentials.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(group_id, session, credentials, opts \\ []) do
    silent = Keyword.get(opts, :silent, false)
    params = build_params(group_id, session, credentials, silent)

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

  @doc "Build URL for leave group endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/leave"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), Session.t(), Credentials.t(), boolean()) :: map()
  def build_params(group_id, _session, credentials, silent \\ false) do
    %{
      grids: [group_id],
      imei: credentials.imei,
      silent: if(silent, do: 1, else: 0),
      language: credentials.language
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
