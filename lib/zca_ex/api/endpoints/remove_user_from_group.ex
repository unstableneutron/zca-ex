defmodule ZcaEx.Api.Endpoints.RemoveUserFromGroup do
  @moduledoc "Remove user(s) from a group"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Remove user(s) from a group.

  ## Parameters
    - group_id: Group ID to remove users from
    - member_id: Single member ID or list of member IDs
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{error_members: [String.t()]}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), String.t() | [String.t()], Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(_group_id, member_id, _session, _credentials)
      when member_id == [] or member_id == "" do
    {:error, %Error{message: "member_id cannot be empty", code: :invalid_input}}
  end

  def call(group_id, member_id, session, credentials) when is_binary(member_id) do
    call(group_id, [member_id], session, credentials)
  end

  def call(group_id, member_ids, session, credentials) when is_list(member_ids) do
    params = build_params(group_id, member_ids, credentials)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session)
        body = build_form_body(%{params: encrypted_params})

        case AccountClient.post(session.uid, url, body, credentials.user_agent) do
          {:ok, response} ->
            case Response.parse(response, session.secret_key) do
              {:ok, data} ->
                {:ok, normalize_response(data)}

              {:error, _} = error ->
                error
            end

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL for remove user from group endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/kickout"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), [String.t()], Credentials.t()) :: map()
  def build_params(group_id, member_ids, credentials) do
    %{
      grid: group_id,
      members: member_ids,
      imei: credentials.imei
    }
  end

  defp normalize_response(data) do
    %{
      error_members: Map.get(data, "errorMembers", [])
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
