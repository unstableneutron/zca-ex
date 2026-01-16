defmodule ZcaEx.Api.Endpoints.ChangeGroupOwner do
  @moduledoc """
  Change group owner endpoint.

  Transfers group ownership to another member.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Change group owner.

  ## Parameters
    - new_owner_id: User ID of the new group owner
    - group_id: Group ID
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{time: integer()}}` on success
    - `{:error, Error.t()}` on failure

  ## Warning
  Be careful when using this function, as it will result in losing group admin rights.
  """
  @spec call(String.t(), String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(new_owner_id, group_id, session, credentials) do
    with :ok <- validate_new_owner_id(new_owner_id),
         :ok <- validate_group_id(group_id),
         {:ok, encrypted_params} <- encrypt_params(session.secret_key, build_params(new_owner_id, group_id, credentials)) do
      url = build_url(session, encrypted_params)

      case AccountClient.get(session.uid, url, credentials.user_agent) do
        {:ok, response} ->
          Response.parse(response, session.secret_key)

        {:error, reason} ->
          {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
      end
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t(), Credentials.t()) :: map()
  def build_params(new_owner_id, group_id, credentials) do
    %{
      grid: group_id,
      newAdminId: new_owner_id,
      imei: credentials.imei,
      language: credentials.language || "vi"
    }
  end

  @doc "Build URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group) <> "/api/group/change-owner"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  defp validate_new_owner_id(nil), do: {:error, %Error{message: "Missing new_owner_id", code: nil}}
  defp validate_new_owner_id(""), do: {:error, %Error{message: "Missing new_owner_id", code: nil}}
  defp validate_new_owner_id(id) when is_binary(id), do: :ok
  defp validate_new_owner_id(_), do: {:error, %Error{message: "Invalid new_owner_id", code: nil}}

  defp validate_group_id(nil), do: {:error, %Error{message: "Missing group_id", code: nil}}
  defp validate_group_id(""), do: {:error, %Error{message: "Missing group_id", code: nil}}
  defp validate_group_id(id) when is_binary(id), do: :ok
  defp validate_group_id(_), do: {:error, %Error{message: "Invalid group_id", code: nil}}

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
