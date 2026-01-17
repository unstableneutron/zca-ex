defmodule ZcaEx.Api.Endpoints.GetLoginInfo do
  @moduledoc """
  Fetch login info from Zalo after authentication.

  Returns user credentials including UID, zpw_enk, and service map.
  Used during QR login finalization and account manager login.
  """

  require Logger

  alias ZcaEx.Crypto.{AesCbc, ParamsEncryptor, SignKey}
  alias ZcaEx.HTTP
  alias ZcaEx.HTTP.Client

  @default_api_type 30
  @default_api_version 645
  @default_language "vi"

  @type opts :: [
          api_type: integer(),
          api_version: integer(),
          language: String.t()
        ]

  @type login_info :: %{
          uid: String.t(),
          zpw_enk: String.t() | nil,
          zpw_service_map_v3: map() | nil
        }

  @doc """
  Fetch login info using the getLoginInfo API.

  ## Parameters
    - cookie_jar_id: The cookie jar ID to use for the request
    - imei: Device IMEI
    - user_agent: Browser user agent string
    - opts: Optional settings (api_type, api_version, language)

  ## Returns
    - `{:ok, login_info}` on success with uid, zpw_enk, zpw_service_map_v3, etc.
    - `{:error, reason}` on failure
  """
  @spec call(term(), String.t(), String.t(), opts()) :: {:ok, map()} | {:error, String.t()}
  def call(cookie_jar_id, imei, user_agent, opts \\ []) do
    api_type = Keyword.get(opts, :api_type, @default_api_type)
    api_version = Keyword.get(opts, :api_version, @default_api_version)
    language = Keyword.get(opts, :language, @default_language)

    encryptor = ParamsEncryptor.new(api_type, imei, System.system_time(:millisecond))
    enc_params = ParamsEncryptor.get_params(encryptor)
    enc_key = ParamsEncryptor.get_encrypt_key(encryptor)

    data = %{
      computer_name: "Web",
      imei: imei,
      language: language,
      ts: System.system_time(:millisecond)
    }

    encrypted_data = ParamsEncryptor.encode_aes(enc_key, Jason.encode!(data), :base64, false)

    sign_params = %{
      zcid: enc_params.zcid,
      zcid_ext: enc_params.zcid_ext,
      enc_ver: enc_params.enc_ver,
      params: encrypted_data,
      type: api_type,
      client_version: api_version
    }

    params =
      sign_params
      |> Map.put(:signkey, SignKey.generate("getlogininfo", sign_params))
      |> Map.put(:nretry, 0)

    url = HTTP.build_url("https://wpa.chat.zalo.me/api/login/getLoginInfo", params)

    headers = [
      {"accept", "*/*"},
      {"accept-language", "vi-VN,vi;q=0.9,en-US;q=0.6,en;q=0.5"},
      {"sec-ch-ua", ~s("Chromium";"v="130", "Google Chrome";"v="130", "Not?A_Brand";"v="99")},
      {"sec-ch-ua-mobile", "?0"},
      {"sec-ch-ua-platform", ~s("Windows")},
      {"sec-fetch-dest", "empty"},
      {"sec-fetch-mode", "cors"},
      {"sec-fetch-site", "same-site"},
      {"referer", "https://chat.zalo.me/"},
      {"user-agent", user_agent}
    ]

    cookies = ZcaEx.CookieJar.Jar.export(cookie_jar_id)
    headers = add_cookie_header(headers, cookies, "https://wpa.chat.zalo.me")

    case Client.get(url, headers) do
      {:ok, %{status: 200, body: body}} ->
        resp = Jason.decode!(body)
        Logger.debug("getLoginInfo response: #{inspect(resp)}")

        if resp["error_code"] == 0 do
          decrypted = AesCbc.decrypt_utf8_key(enc_key, resp["data"], :base64)
          Logger.debug("Decrypted login info: #{inspect(decrypted)}")
          login_data = Jason.decode!(decrypted)

          case login_data do
            %{"error_code" => 0, "data" => data} when is_map(data) ->
              {:ok, data}

            %{"error_code" => code, "error_message" => msg} when code != 0 ->
              {:error, "Login failed (#{code}): #{msg}"}

            %{"uid" => _} = data ->
              {:ok, data}

            _ ->
              {:ok, login_data}
          end
        else
          {:error, resp["error_message"] || "Login failed"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp add_cookie_header(headers, cookies, url) do
    uri = URI.parse(url)

    matching_cookies =
      cookies
      |> Enum.filter(fn cookie ->
        domain = cookie["domain"] || ""
        path = cookie["path"] || "/"

        domain_match =
          String.ends_with?(uri.host || "", String.trim_leading(domain, ".")) or
            domain == uri.host

        path_match = String.starts_with?(uri.path || "/", path)
        domain_match and path_match
      end)
      |> Enum.map(fn cookie -> "#{cookie["name"]}=#{cookie["value"]}" end)
      |> Enum.join("; ")

    if matching_cookies != "" do
      headers ++ [{"cookie", matching_cookies}]
    else
      headers
    end
  end
end
