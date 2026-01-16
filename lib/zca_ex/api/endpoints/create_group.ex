defmodule ZcaEx.Api.Endpoints.CreateGroup do
  @moduledoc "Create a new group"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Create a new group.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Options
      - `:members` - List of member IDs (required, at least one)
      - `:name` - Group name (optional, defaults to timestamp)

  ## Returns
    - `{:ok, %{group_id: String.t(), success_members: [String.t()], error_members: [String.t()]}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), keyword()) ::
          {:ok, %{group_id: String.t(), success_members: [String.t()], error_members: [String.t()]}}
          | {:error, Error.t()}
  def call(session, credentials, opts \\ []) do
    members = Keyword.get(opts, :members, [])

    case validate_members(members) do
      :ok ->
        name = Keyword.get(opts, :name)
        params = build_params(credentials.imei, members, name, credentials.language)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(session, encrypted_params)

            case AccountClient.post(session.uid, url, "", credentials.user_agent) do
              {:ok, response} ->
                with {:ok, data} <- Response.parse(response, session.secret_key) do
                  {:ok, transform_response(data)}
                end

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

  @doc "Validate members list"
  @spec validate_members([String.t()]) :: :ok | {:error, Error.t()}
  def validate_members([]), do: {:error, %Error{message: "Group must have at least one member", code: nil}}
  def validate_members(members) when is_list(members), do: :ok
  def validate_members(_), do: {:error, %Error{message: "Members must be a list", code: nil}}

  @doc "Build URL for create group endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group) <> "/api/group/create/v2"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/create/v2"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), [String.t()], String.t() | nil, String.t()) :: map()
  def build_params(imei, members, name \\ nil, language \\ "vi") do
    client_id = System.system_time(:millisecond)

    params = %{
      clientId: client_id,
      gname: to_string(client_id),
      gdesc: nil,
      members: members,
      membersTypes: Enum.map(members, fn _ -> -1 end),
      nameChanged: 0,
      createLink: 1,
      clientLang: language,
      imei: imei,
      zsource: 601
    }

    if name && String.length(name) > 0 do
      %{params | gname: name, nameChanged: 1}
    else
      params
    end
  end

  defp transform_response(data) do
    %{
      group_id: Map.get(data, "groupId") || Map.get(data, :groupId),
      success_members: Map.get(data, "sucessMembers") || Map.get(data, :sucessMembers) || [],
      error_members: Map.get(data, "errorMembers") || Map.get(data, :errorMembers) || []
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
