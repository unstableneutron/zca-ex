defmodule ZcaEx.Api.Endpoints.JoinGroupLink do
  @moduledoc "Join a group via invite link"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Join a group using an invite link.

  ## Parameters
    - link: Invite link string
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, map()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(link, session, credentials) do
    case validate_link(link) do
      :ok ->
        params = build_params(link, credentials.language)

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

      {:error, _} = error ->
        error
    end
  end

  @doc "Validate link is non-empty"
  @spec validate_link(String.t()) :: :ok | {:error, Error.t()}
  def validate_link(link) when is_binary(link) and byte_size(link) > 0, do: :ok
  def validate_link(_), do: {:error, %Error{message: "link cannot be empty", code: nil}}

  @doc "Build URL for join group link endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group) <> "/api/group/link/join"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/link/join"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t()) :: map()
  def build_params(link, language) do
    %{
      link: link,
      clientLang: language
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
