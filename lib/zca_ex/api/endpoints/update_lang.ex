defmodule ZcaEx.Api.Endpoints.UpdateLang do
  @moduledoc "Update language preference"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type language :: :vi | :en | String.t()

  @doc """
  Update language preference.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - language: Language code - :vi, :en, or string "VI"/"EN" (default: :vi)

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), language()) ::
          {:ok, :success} | {:error, Error.t()}
  def call(session, credentials, language \\ :vi) do
    with :ok <- validate_language(language) do
      do_call(session, credentials, language)
    end
  end

  defp do_call(session, credentials, language) do
    params = build_params(language)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
          {:ok, response} ->
            with {:ok, _data} <- Response.parse(response, session.secret_key) do
              {:ok, :success}
            end

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params(language()) :: map()
  def build_params(language) do
    %{language: normalize_language(language)}
  end

  @doc "Validate language"
  @spec validate_language(term()) :: :ok | {:error, Error.t()}
  def validate_language(:vi), do: :ok
  def validate_language(:en), do: :ok
  def validate_language("VI"), do: :ok
  def validate_language("EN"), do: :ok
  def validate_language("vi"), do: :ok
  def validate_language("en"), do: :ok

  def validate_language(_),
    do: {:error, %Error{message: "Language must be :vi, :en, \"VI\", or \"EN\"", code: nil}}

  @doc "Normalize language to API format"
  @spec normalize_language(language()) :: String.t()
  def normalize_language(:vi), do: "VI"
  def normalize_language(:en), do: "EN"
  def normalize_language(lang) when is_binary(lang), do: String.upcase(lang)

  @doc "Build URL for update lang endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session) <> "/api/social/profile/updatelang"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session) <> "/api/social/profile/updatelang"
    Url.build_for_session(base_url, %{}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["profile"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for profile"
    end
  end
end
