defmodule ZcaEx.Api.Endpoints.GetGroupInviteBoxList do
  @moduledoc "Get group invite box list"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Get list of pending group invitations.

  ## Parameters
    - opts: Optional params (mpage, page, invPerPage, mcount)
    - session: Authenticated session
    - credentials: Account credentials

  ## Options
    - mpage: Member page number (default: 1)
    - page: Page number (default: 0)
    - invPerPage: Invitations per page (default: 12)
    - mcount: Member count (default: 10)

  ## Returns
    - `{:ok, %{}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(keyword(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(opts \\ [], session, credentials) do
    params = build_params(opts)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
          {:ok, response} ->
            Response.parse(response, session.secret_key)

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL for get group invite box list endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group) <> "/api/group/inv-box/list"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/inv-box/list"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(keyword()) :: map()
  def build_params(opts \\ []) do
    %{
      mpage: Keyword.get(opts, :mpage, 1),
      page: Keyword.get(opts, :page, 0),
      invPerPage: Keyword.get(opts, :invPerPage, 12),
      mcount: Keyword.get(opts, :mcount, 10),
      lastGroupId: nil,
      avatar_size: 120,
      member_avatar_size: 120
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
