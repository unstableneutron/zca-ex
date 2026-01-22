defmodule ZcaEx.Api.Endpoints.UnblockUser do
  @moduledoc "Unblock a previously blocked user"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Unblock a user.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - user_id: User ID to unblock (required, non-empty string)

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), String.t()) :: {:ok, :success} | {:error, Error.t()}
  def call(session, credentials, user_id) do
    case validate_user_id(user_id) do
      :ok ->
        params = build_params(user_id, credentials.imei)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(session, encrypted_params)

            case AccountClient.post(session.uid, url, "", credentials.user_agent) do
              {:ok, response} ->
                case Response.parse(response, session.secret_key) do
                  {:ok, _data} -> {:ok, :success}
                  {:error, _} = error -> error
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

  @doc "Validate user_id"
  @spec validate_user_id(term()) :: :ok | {:error, Error.t()}
  def validate_user_id(user_id) when is_binary(user_id) and byte_size(user_id) > 0, do: :ok
  def validate_user_id(""), do: {:error, %Error{message: "user_id is required", code: nil}}
  def validate_user_id(nil), do: {:error, %Error{message: "user_id is required", code: nil}}

  def validate_user_id(_),
    do: {:error, %Error{message: "user_id must be a non-empty string", code: nil}}

  @doc "Build URL for unblock user endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session) <> "/api/friend/unblock"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session) <> "/api/friend/unblock"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t()) :: map()
  def build_params(user_id, imei) do
    %{
      fid: user_id,
      imei: imei
    }
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["friend", Access.at(0)]) do
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for friend"
    end
  end
end
