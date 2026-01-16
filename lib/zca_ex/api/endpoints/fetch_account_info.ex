defmodule ZcaEx.Api.Endpoints.FetchAccountInfo do
  @moduledoc "Fetch current account information"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type user_info :: %{
          id: String.t() | nil,
          name: String.t() | nil,
          avatar: String.t() | nil,
          phone_number: String.t() | nil,
          gender: integer() | nil,
          dob: String.t() | nil,
          status: String.t() | nil,
          raw: map()
        }

  @doc """
  Fetch current account information.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, user_info()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t()) :: {:ok, user_info()} | {:error, Error.t()}
  def call(session, credentials) do
    params = build_params()

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
          {:ok, response} ->
            case Response.parse(response, session.secret_key) do
              {:ok, data} -> {:ok, transform_response(data)}
              {:error, _} = error -> error
            end

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL for fetch account info endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :profile) <> "/api/social/profile/me-v2"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :profile) <> "/api/social/profile/me-v2"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption (empty params for this endpoint)"
  @spec build_params() :: map()
  def build_params do
    %{}
  end

  @doc "Transform API response to Elixir-style keys"
  @spec transform_response(map()) :: user_info()
  def transform_response(data) do
    %{
      id: data["userId"] || data[:userId],
      name: data["displayName"] || data[:displayName] || data["zaloName"] || data[:zaloName],
      avatar: data["avatar"] || data[:avatar],
      phone_number: data["phoneNumber"] || data[:phoneNumber],
      gender: data["gender"] || data[:gender],
      dob: data["dob"] || data[:dob],
      status: data["status"] || data[:status],
      raw: data
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
