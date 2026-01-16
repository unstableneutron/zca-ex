defmodule ZcaEx.Api.Endpoints.JoinGroupInviteBox do
  @moduledoc "Join group from invite box"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Accept a group invitation from the invite box.

  ## Parameters
    - group_id: Group ID to join
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(group_id, session, credentials) do
    case validate_group_id(group_id) do
      :ok ->
        params = build_params(group_id, credentials.language)

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

  @doc "Build URL for join group invite box endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group) <> "/api/group/inv-box/join"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/inv-box/join"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t()) :: map()
  def build_params(group_id, language) do
    %{
      grid: group_id,
      lang: language
    }
  end

  @doc "Validate group_id"
  @spec validate_group_id(any()) :: :ok | {:error, Error.t()}
  def validate_group_id(nil), do: {:error, %Error{message: "Group ID is required", code: nil}}
  def validate_group_id(""), do: {:error, %Error{message: "Group ID cannot be empty", code: nil}}
  def validate_group_id(id) when is_binary(id), do: :ok
  def validate_group_id(_), do: {:error, %Error{message: "Group ID must be a string", code: nil}}

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
