defmodule ZcaEx.Api.Endpoints.ReviewPendingMemberRequest do
  @moduledoc "Review pending group member requests (approve/reject)"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Review pending member requests for a group (approve or reject).

  ## Parameters
    - group_id: Group ID
    - member_ids: Single member ID or list of member IDs
    - is_approve: Boolean - true to approve, false to reject
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, map()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), String.t() | [String.t()], boolean(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(_group_id, member_ids, _is_approve, _session, _credentials)
      when member_ids == [] or member_ids == "" do
    {:error, %Error{message: "member_ids cannot be empty", code: :invalid_input}}
  end

  def call(_group_id, _member_ids, is_approve, _session, _credentials)
      when not is_boolean(is_approve) do
    {:error, %Error{message: "is_approve must be a boolean", code: :invalid_input}}
  end

  def call(group_id, member_id, is_approve, session, credentials) when is_binary(member_id) do
    call(group_id, [member_id], is_approve, session, credentials)
  end

  def call(group_id, member_ids, is_approve, session, credentials) when is_list(member_ids) do
    normalized_member_ids = normalize_member_ids(member_ids)
    params = build_params(group_id, normalized_member_ids, is_approve)

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

  @doc "Build base URL for review pending member request endpoint"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    get_service_url(session, :group) <> "/api/group/pending-mems/review"
  end

  @doc "Build full URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = build_base_url(session)
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), [String.t()], boolean()) :: map()
  def build_params(group_id, member_ids, true) do
    %{grid: group_id, members: member_ids, isApprove: 1}
  end

  def build_params(group_id, member_ids, false) do
    %{grid: group_id, members: member_ids, isApprove: 0}
  end

  @doc "Normalize member_ids to a list"
  @spec normalize_member_ids(String.t() | [String.t()]) :: [String.t()]
  def normalize_member_ids(member_id) when is_binary(member_id), do: [member_id]
  def normalize_member_ids(member_ids) when is_list(member_ids), do: member_ids

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
