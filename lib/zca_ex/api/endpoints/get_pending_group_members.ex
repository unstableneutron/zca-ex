defmodule ZcaEx.Api.Endpoints.GetPendingGroupMembers do
  @moduledoc "Get pending group member requests"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Get pending group member requests.

  ## Parameters
    - group_id: Group ID to get pending members for
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, map()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(group_id, session, credentials) do
    with :ok <- validate_group_id(group_id) do
      params = build_params(group_id, credentials)

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
  end

  @spec validate_group_id(term()) :: :ok | {:error, Error.t()}
  defp validate_group_id(group_id) when is_binary(group_id) and byte_size(group_id) > 0, do: :ok
  defp validate_group_id(_), do: {:error, %Error{message: "group_id cannot be empty", code: :invalid_input}}

  @doc "Build base URL for get pending group members endpoint"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group) <> "/api/group/pending-mems/list"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build full URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = build_base_url(session)
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), Credentials.t()) :: map()
  def build_params(group_id, credentials) do
    %{
      grid: group_id,
      imei: credentials.imei
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
