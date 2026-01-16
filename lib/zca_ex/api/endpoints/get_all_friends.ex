defmodule ZcaEx.Api.Endpoints.GetAllFriends do
  @moduledoc "Get all friends list"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @default_count 20000
  @default_page 1

  @doc """
  Get all friends.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Options
      - `:count` - Page size (default: 20000)
      - `:page` - Page number (default: 1)

  ## Returns
    - `{:ok, [map()]}` list of friends on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), keyword()) :: {:ok, [map()]} | {:error, Error.t()}
  def call(session, credentials, opts \\ []) do
    count = Keyword.get(opts, :count, @default_count)
    page = Keyword.get(opts, :page, @default_page)

    params = build_params(credentials.imei, count, page)

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

  @doc "Build URL for get all friends endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :profile) <> "/api/social/friend/getfriends"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :profile) <> "/api/social/friend/getfriends"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), integer(), integer()) :: map()
  def build_params(imei, count \\ @default_count, page \\ @default_page) do
    %{
      incInvalid: 1,
      page: page,
      count: count,
      avatar_size: 120,
      actiontime: 0,
      imei: imei
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
