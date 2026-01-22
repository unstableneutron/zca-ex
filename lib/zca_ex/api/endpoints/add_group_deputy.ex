defmodule ZcaEx.Api.Endpoints.AddGroupDeputy do
  @moduledoc "Add group deputy (admin)"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Add deputy (admin) to a group.

  ## Parameters
    - group_id: Group ID
    - member_id: Single member ID or list of member IDs to add as deputies
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), String.t() | [String.t()], Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(group_id, member_id, session, credentials) do
    member_ids = normalize_member_ids(member_id)

    case validate_member_ids(member_ids) do
      :ok ->
        params = build_params(group_id, member_ids, credentials.imei)

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

  @doc "Build URL for add group deputy endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group) <> "/api/group/admins/add"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/admins/add"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), [String.t()], String.t()) :: map()
  def build_params(group_id, member_ids, imei) do
    %{
      grid: group_id,
      members: member_ids,
      imei: imei
    }
  end

  @doc "Normalize member_id to list"
  @spec normalize_member_ids(String.t() | [String.t()]) :: [String.t()]
  def normalize_member_ids(member_id) when is_binary(member_id), do: [member_id]
  def normalize_member_ids(member_ids) when is_list(member_ids), do: member_ids

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
