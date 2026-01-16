defmodule ZcaEx.Api.Endpoints.UpdateProfile do
  @moduledoc "Update account profile information"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type profile_data :: %{
          name: String.t(),
          dob: String.t(),
          gender: integer()
        }

  @type biz_data :: %{
          optional(:description) => String.t(),
          optional(:category) => String.t(),
          optional(:address) => String.t(),
          optional(:website) => String.t(),
          optional(:email) => String.t()
        }

  @doc """
  Update account profile.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - profile: Profile data with name, dob, gender
    - opts: Options
      - `:biz` - Business info (optional)

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), profile_data(), keyword()) ::
          {:ok, :success} | {:error, Error.t()}
  def call(session, credentials, profile, opts \\ []) do
    with :ok <- validate_profile(profile) do
      biz = Keyword.get(opts, :biz, %{})
      params = build_params(profile, biz, credentials.language)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
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
    end
  end

  @doc "Validate profile data"
  @spec validate_profile(map()) :: :ok | {:error, Error.t()}
  def validate_profile(%{name: name}) when is_binary(name) and byte_size(name) > 0, do: :ok

  def validate_profile(%{name: _}),
    do: {:error, %Error{message: "Name must be a non-empty string", code: nil}}

  def validate_profile(_), do: {:error, %Error{message: "Profile must contain name", code: nil}}

  @doc "Build URL for update profile endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session, :profile) <> "/api/social/profile/update"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(profile_data(), biz_data(), String.t()) :: map()
  def build_params(profile, biz, language) do
    profile_data = %{
      name: profile[:name] || Map.get(profile, :name),
      dob: profile[:dob] || Map.get(profile, :dob),
      gender: profile[:gender] || Map.get(profile, :gender)
    }

    biz_data = %{
      desc: biz[:description],
      cate: biz[:category],
      addr: biz[:address],
      website: biz[:website],
      email: biz[:email]
    }

    {:ok, profile_json} = Jason.encode(profile_data)
    {:ok, biz_json} = Jason.encode(biz_data)

    %{
      profile: profile_json,
      biz: biz_json,
      language: language
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
