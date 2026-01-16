defmodule ZcaEx.Api.Endpoints.DeleteGroupInviteBox do
  @moduledoc "Delete group invite box invitations"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Delete/reject group invitations.

  ## Parameters
    - group_ids: Single group ID or list of group IDs to reject
    - opts: Optional params
    - session: Authenticated session
    - credentials: Account credentials

  ## Options
    - block: Block future invites from these groups (default: false)

  ## Returns
    - `{:ok, %{}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t() | [String.t()], keyword(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(group_ids, opts \\ [], session, credentials) do
    normalized_ids = normalize_group_ids(group_ids)

    case validate_group_ids(normalized_ids) do
      :ok ->
        case build_params(normalized_ids, opts) do
          {:ok, params} ->
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

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL for delete group invite box endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group) <> "/api/group/inv-box/mdel-inv"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/inv-box/mdel-inv"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params([String.t()], keyword()) :: {:ok, map()} | {:error, Error.t()}
  def build_params(group_ids, opts \\ []) do
    invitations = Enum.map(group_ids, fn grid -> %{grid: grid} end)

    case Jason.encode(invitations) do
      {:ok, invitations_json} ->
        {:ok,
         %{
           invitations: invitations_json,
           block: if(Keyword.get(opts, :block, false), do: 1, else: 0)
         }}

      {:error, reason} ->
        {:error, %Error{message: "Failed to encode invitations: #{inspect(reason)}", code: nil}}
    end
  end

  @doc "Normalize group_ids to list"
  @spec normalize_group_ids(String.t() | [String.t()] | nil | term()) :: [String.t()]
  def normalize_group_ids(nil), do: []
  def normalize_group_ids(group_id) when is_binary(group_id), do: [group_id]
  def normalize_group_ids(group_ids) when is_list(group_ids), do: group_ids
  def normalize_group_ids(_), do: []

  @doc "Validate group_ids"
  @spec validate_group_ids([String.t()]) :: :ok | {:error, Error.t()}
  def validate_group_ids([]), do: {:error, %Error{message: "Group IDs cannot be empty", code: :invalid_input}}
  def validate_group_ids(_), do: :ok

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
