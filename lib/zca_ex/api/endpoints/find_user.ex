defmodule ZcaEx.Api.Endpoints.FindUser do
  @moduledoc """
  Find a user by phone number.

  Searches for a Zalo user using their phone number. Automatically converts
  local Vietnamese phone format (0xxx) to international format (84xxx) when
  the language is set to "vi".
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type user_info :: %{
          uid: String.t(),
          zalo_name: String.t(),
          display_name: String.t(),
          avatar: String.t(),
          cover: String.t(),
          status: String.t(),
          gender: integer(),
          dob: integer(),
          sdob: String.t(),
          global_id: String.t(),
          biz_pkg: map()
        }

  @doc """
  Find a user by phone number.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - phone_number: Phone number to search for

  ## Returns
    - `{:ok, user_info()}` on success
    - `{:error, Error.t()}` on failure

  ## Phone Number Normalization
  If the phone number starts with "0" and the language is "vi", the leading
  "0" is replaced with "84" (Vietnam country code).
  """
  @spec call(Session.t(), Credentials.t(), String.t()) :: {:ok, user_info()} | {:error, Error.t()}
  def call(session, credentials, phone_number) do
    case validate_phone_number(phone_number) do
      :ok ->
        normalized_phone = normalize_phone(phone_number, credentials.language)
        do_call(session, credentials, normalized_phone)

      {:error, _} = error ->
        error
    end
  end

  defp do_call(session, credentials, normalized_phone) do
    params = build_params(normalized_phone, credentials.imei, credentials.language)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
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
  end

  @doc "Validate phone number is non-empty"
  @spec validate_phone_number(term()) :: :ok | {:error, Error.t()}
  def validate_phone_number(nil),
    do: {:error, %Error{message: "Phone number is required", code: nil}}

  def validate_phone_number(""),
    do: {:error, %Error{message: "Phone number cannot be empty", code: nil}}

  def validate_phone_number(phone) when is_binary(phone), do: :ok

  def validate_phone_number(_),
    do: {:error, %Error{message: "Phone number must be a string", code: nil}}

  @doc "Normalize phone number for Vietnamese locale"
  @spec normalize_phone(String.t(), String.t()) :: String.t()
  def normalize_phone(phone, "vi") when is_binary(phone) do
    if String.starts_with?(phone, "0") do
      "84" <> String.slice(phone, 1..-1//1)
    else
      phone
    end
  end

  def normalize_phone(phone, _language), do: phone

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t(), String.t()) :: map()
  def build_params(phone, imei, language) do
    %{
      phone: phone,
      avatar_size: 240,
      language: language,
      imei: imei,
      reqSrc: 40
    }
  end

  @doc "Build URL for find user endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session) <> "/api/friend/profile/get"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session) <> "/api/friend/profile/get"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Transform API response to structured user data"
  @spec transform_response(map()) :: user_info()
  def transform_response(data) do
    %{
      uid: get_string(data, "userId", :userId),
      zalo_name: get_string(data, "zaloName", :zaloName),
      display_name: get_string(data, "displayName", :displayName),
      avatar: get_string(data, "avatar", :avatar),
      cover: get_string(data, "cover", :cover),
      status: get_string(data, "status", :status),
      gender: get_integer(data, "gender", :gender),
      dob: get_integer(data, "dob", :dob),
      sdob: get_string(data, "sdob", :sdob),
      global_id: get_string(data, "globalId", :globalId),
      biz_pkg: get_map(data, "bizPkg", :bizPkg)
    }
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["friend", Access.at(0)]) do
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for friend"
    end
  end

  defp get_string(data, string_key, atom_key) do
    (Map.get(data, string_key) || Map.get(data, atom_key, "")) |> to_string_safe()
  end

  defp get_integer(data, string_key, atom_key) do
    case Map.get(data, string_key) || Map.get(data, atom_key) do
      val when is_integer(val) -> val
      _ -> 0
    end
  end

  defp get_map(data, string_key, atom_key) do
    case Map.get(data, string_key) || Map.get(data, atom_key) do
      val when is_map(val) -> val
      _ -> %{}
    end
  end

  defp to_string_safe(nil), do: ""
  defp to_string_safe(val) when is_binary(val), do: val
  defp to_string_safe(_), do: ""
end
