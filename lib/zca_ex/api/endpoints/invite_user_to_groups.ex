defmodule ZcaEx.Api.Endpoints.InviteUserToGroups do
  @moduledoc "Invite a user to multiple groups"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Invite a user to one or multiple groups.

  ## Parameters
    - group_ids: Single group ID or list of group IDs
    - user_id: User ID to invite
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, map()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t() | [String.t()], String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(group_ids, _user_id, _session, _credentials)
      when group_ids == [] or group_ids == "" do
    {:error, %Error{message: "group_ids cannot be empty", code: :invalid_input}}
  end

  def call(_group_ids, user_id, _session, _credentials) when user_id == "" do
    {:error, %Error{message: "user_id cannot be empty", code: :invalid_input}}
  end

  def call(group_id, user_id, session, credentials) when is_binary(group_id) do
    call([group_id], user_id, session, credentials)
  end

  def call(group_ids, user_id, session, credentials) when is_list(group_ids) do
    normalized_group_ids = normalize_group_ids(group_ids)
    params = build_params(normalized_group_ids, user_id, credentials)

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

  @doc "Build base URL for invite user to groups endpoint"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    get_service_url(session, :group) <> "/api/group/invite/multi"
  end

  @doc "Build full URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = build_base_url(session)
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build params for encryption"
  @spec build_params([String.t()], String.t(), Credentials.t()) :: map()
  def build_params(group_ids, user_id, credentials) do
    %{
      grids: group_ids,
      member: user_id,
      memberType: -1,
      srcInteraction: 2,
      clientLang: credentials.language
    }
  end

  @doc "Normalize group_ids to a list"
  @spec normalize_group_ids(String.t() | [String.t()]) :: [String.t()]
  def normalize_group_ids(group_id) when is_binary(group_id), do: [group_id]
  def normalize_group_ids(group_ids) when is_list(group_ids), do: group_ids

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
