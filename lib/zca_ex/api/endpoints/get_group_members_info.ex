defmodule ZcaEx.Api.Endpoints.GetGroupMembersInfo do
  @moduledoc "Get group members info"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Get group members info.

  ## Parameters
    - member_id: Single member ID or list of member IDs
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, map()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t() | [String.t()], Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(member_id, session, credentials) do
    member_ids = normalize_member_ids(member_id)

    case validate_member_ids(member_ids) do
      :ok ->
        params = build_params(member_ids)

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

  @doc "Build URL for get group members info endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :profile) <> "/api/social/group/members"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :profile) <> "/api/social/group/members"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params([String.t()]) :: map()
  def build_params(member_ids) do
    %{
      friend_pversion_map: Enum.map(member_ids, &append_version_suffix/1)
    }
  end

  @doc "Normalize member_id to list"
  @spec normalize_member_ids(String.t() | [String.t()]) :: [String.t()]
  def normalize_member_ids(member_id) when is_binary(member_id), do: [member_id]
  def normalize_member_ids(member_ids) when is_list(member_ids), do: member_ids

  @doc "Append _0 suffix to member_id if not already present"
  @spec append_version_suffix(String.t()) :: String.t()
  def append_version_suffix(member_id) do
    if String.ends_with?(member_id, "_0") do
      member_id
    else
      "#{member_id}_0"
    end
  end

  @spec validate_member_ids([String.t()]) :: :ok | {:error, Error.t()}
  defp validate_member_ids([]),
    do: {:error, %Error{message: "member_id cannot be empty", code: nil}}

  defp validate_member_ids(_), do: :ok

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
