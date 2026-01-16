defmodule ZcaEx.Api.Endpoints.GetGroupInviteBoxInfo do
  @moduledoc "Get group invite box info"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Get invite box info for a specific group.

  ## Parameters
    - group_id: Group ID
    - opts: Optional params (mcount, mpage)
    - session: Authenticated session
    - credentials: Account credentials

  ## Options
    - mcount: Member count per page (default: 10)
    - mpage: Member page number (default: 1)

  ## Returns
    - `{:ok, %{}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), keyword(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(group_id, opts \\ [], session, credentials) do
    case validate_group_id(group_id) do
      :ok ->
        params = build_params(group_id, opts)

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

  @doc "Build URL for get group invite box info endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group) <> "/api/group/inv-box/inv-info"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/inv-box/inv-info"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), keyword()) :: map()
  def build_params(group_id, opts \\ []) do
    %{
      grId: group_id,
      mcount: Keyword.get(opts, :mcount, 10),
      mpage: Keyword.get(opts, :mpage, 1)
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
