defmodule ZcaEx.Api.Endpoints.GetUserInfo do
  @moduledoc "Get user profile information"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Get user info by ID(s).

  ## Parameters
    - user_ids: Single user ID or list of user IDs
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{changed_profiles: map(), unchanged_profiles: map()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t() | [String.t()], Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(user_ids, session, credentials) when is_binary(user_ids) do
    call([user_ids], session, credentials)
  end

  def call(user_ids, session, credentials) when is_list(user_ids) do
    user_ids = normalize_user_ids(user_ids)

    params = %{
      phonebook_version: get_in(session.extra_ver, ["phonebook"]) || 0,
      friend_pversion_map: user_ids,
      avatar_size: 120,
      language: credentials.language,
      show_online_status: 1,
      imei: credentials.imei
    }

    with {:ok, encrypted_params} <- encrypt_params(session.secret_key, params),
         {:ok, url} <- build_url(session) do
      body = build_form_body(%{params: encrypted_params})

      case AccountClient.post(credentials.imei, url, body, credentials.user_agent) do
        {:ok, response} ->
          Response.parse(response, session.secret_key)

        {:error, reason} ->
          {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
      end
    end
  end

  @doc "Build URL for get user info endpoint"
  @spec build_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_url(session) do
    case get_service_url(session, :profile) do
      {:ok, service_url} ->
        base_url = service_url <> "/api/social/friend/getprofiles/v2"
        {:ok, Url.build_for_session(base_url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Normalize user IDs by adding _0 suffix if not present"
  @spec normalize_user_ids([String.t()]) :: [String.t()]
  def normalize_user_ids(user_ids) do
    Enum.map(user_ids, fn id ->
      if String.contains?(id, "_") do
        id
      else
        "#{id}_0"
      end
    end)
  end

  @doc "Build params for encryption"
  @spec build_params([String.t()], Session.t(), Credentials.t()) :: map()
  def build_params(user_ids, session, credentials) do
    %{
      phonebook_version: get_in(session.extra_ver, ["phonebook"]) || 0,
      friend_pversion_map: normalize_user_ids(user_ids),
      avatar_size: 120,
      language: credentials.language,
      show_online_status: 1,
      imei: credentials.imei
    }
  end

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, %Error{message: "Service URL not found for #{service}", code: nil}}
    end
  end
end
