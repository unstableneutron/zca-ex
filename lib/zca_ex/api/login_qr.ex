defmodule ZcaEx.Api.LoginQR do
  @moduledoc """
  QR code login flow for Zalo authentication.

  This module implements a GenServer that manages the multi-step QR login process:
  1. Load login page and extract version
  2. Get login info
  3. Verify client
  4. Generate QR code
  5. Wait for scan (long-poll)
  6. Wait for confirm (long-poll)
  7. Check session
  8. Get user info
  9. Fetch login session (getLoginInfo + getServerInfo)

  Events are sent to a callback process as the flow progresses.
  """

  use GenServer

  require Logger

  alias ZcaEx.Account.Session
  alias ZcaEx.Api.LoginQR.Events
  alias ZcaEx.CookieJar.Jar, as: CookieJar
  alias ZcaEx.Crypto.{AesCbc, ParamsEncryptor, SignKey}
  alias ZcaEx.Error
  alias ZcaEx.HTTP
  alias ZcaEx.HTTP.Client

  @qr_timeout_ms 100_000

  @type state ::
          :initializing
          | :waiting_scan
          | :waiting_confirm
          | :complete
          | :aborted
          | :expired
          | :error

  @type t :: %{
          state: state(),
          callback_pid: pid() | nil,
          cookie_jar_id: term(),
          user_agent: String.t(),
          version: String.t() | nil,
          qr_code: String.t() | nil,
          qr_timer: reference() | nil,
          abort_ref: reference() | nil
        }

  @version_regex ~r/https:\/\/stc-zlogin\.zdn\.vn\/main-([\d.]+)\.js/

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Start QR login and send events to callback_pid"
  @spec start(pid(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start(callback_pid, opts \\ []) do
    opts = Keyword.put(opts, :callback_pid, callback_pid)
    start_link(opts)
  end

  @doc "Abort the login flow"
  @spec abort(pid()) :: :ok
  def abort(pid) do
    GenServer.cast(pid, :abort)
  end

  @doc "Retry QR generation (start fresh)"
  @spec retry(pid()) :: :ok
  def retry(pid) do
    GenServer.cast(pid, :retry)
  end

  @doc "Extract version from login page HTML"
  @spec extract_version(String.t()) :: {:ok, String.t()} | :error
  def extract_version(html) do
    case Regex.run(@version_regex, html) do
      [_, version] -> {:ok, version}
      _ -> :error
    end
  end

  @impl true
  def init(opts) do
    callback_pid = Keyword.get(opts, :callback_pid)
    user_agent = Keyword.get(opts, :user_agent, default_user_agent())
    cookie_jar_id = make_ref()

    {:ok, _jar_pid} = CookieJar.start_link(account_id: cookie_jar_id)

    state = %{
      state: :initializing,
      callback_pid: callback_pid,
      cookie_jar_id: cookie_jar_id,
      user_agent: user_agent,
      version: nil,
      qr_code: nil,
      qr_timer: nil,
      abort_ref: nil
    }

    {:ok, state, {:continue, :start_flow}}
  end

  @impl true
  def handle_continue(:start_flow, state) do
    abort_ref = make_ref()
    state = %{state | abort_ref: abort_ref}
    send(self(), {:run_flow, abort_ref})
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    stop_cookie_jar(state.cookie_jar_id)
  end

  @impl true
  def handle_cast(:abort, state) do
    cancel_qr_timer(state)
    state = %{state | state: :aborted, abort_ref: nil}
    {:stop, :normal, state}
  end

  def handle_cast(:retry, state) do
    cancel_qr_timer(state)
    stop_cookie_jar(state.cookie_jar_id)

    new_cookie_jar_id = make_ref()
    {:ok, _jar_pid} = CookieJar.start_link(account_id: new_cookie_jar_id)

    abort_ref = make_ref()

    state = %{
      state
      | state: :initializing,
        qr_code: nil,
        qr_timer: nil,
        abort_ref: abort_ref,
        cookie_jar_id: new_cookie_jar_id
    }

    send(self(), {:run_flow, abort_ref})
    {:noreply, state}
  end

  defp stop_cookie_jar(cookie_jar_id) do
    case Registry.lookup(ZcaEx.Registry, {:cookie_jar, cookie_jar_id}) do
      [{pid, _}] -> GenServer.stop(pid, :normal)
      [] -> :ok
    end
  end

  @impl true
  def handle_info({:run_flow, abort_ref}, %{abort_ref: abort_ref} = state) do
    case run_login_flow(state) do
      {:ok, %{state: :complete} = new_state} ->
        {:stop, :normal, new_state}

      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, error} ->
        send_event(state, Events.login_error(error))
        {:stop, :normal, %{state | state: :error}}
    end
  end

  def handle_info({:run_flow, _old_ref}, state) do
    {:noreply, state}
  end

  def handle_info({:qr_expired, abort_ref}, %{abort_ref: abort_ref} = state) do
    send_event(state, Events.qr_expired())
    new_abort_ref = make_ref()
    {:noreply, %{state | qr_timer: nil, state: :expired, abort_ref: new_abort_ref}}
  end

  def handle_info({:qr_expired, _old_ref}, state) do
    {:noreply, state}
  end

  def handle_info({:continue_waiting_scan, abort_ref, code}, %{abort_ref: abort_ref} = state) do
    case waiting_scan(state, code) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, error} ->
        send_event(state, Events.login_error(error))
        {:stop, :normal, %{state | state: :error}}
    end
  end

  def handle_info({:continue_waiting_scan, _old_ref, _code}, state) do
    {:noreply, state}
  end

  def handle_info({:continue_waiting_confirm, abort_ref, code}, %{abort_ref: abort_ref} = state) do
    case waiting_confirm(state, code) do
      {:ok, %{state: :complete} = new_state} ->
        {:stop, :normal, new_state}

      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, error} ->
        send_event(state, Events.login_error(error))
        {:stop, :normal, %{state | state: :error}}
    end
  end

  def handle_info({:continue_waiting_confirm, _old_ref, _code}, state) do
    {:noreply, state}
  end

  defp run_login_flow(state) do
    with {:ok, version} <- load_login_page(state),
         state = %{state | version: version},
         :ok <- get_login_info(state),
         :ok <- verify_client(state),
         {:ok, qr_data} <- generate_qr(state) do
      options = %{
        enabled_check_ocr: qr_data["options"]["enabledCheckOCR"] || false,
        enabled_multi_layer: qr_data["options"]["enabledMultiLayer"] || false
      }

      code = qr_data["code"]
      image = strip_data_uri(qr_data["image"])

      send_event(state, Events.qr_generated(code, image, options))

      qr_timer = Process.send_after(self(), {:qr_expired, state.abort_ref}, @qr_timeout_ms)
      state = %{state | qr_code: code, qr_timer: qr_timer, state: :waiting_scan}

      send(self(), {:continue_waiting_scan, state.abort_ref, code})

      {:ok, state}
    end
  end

  defp waiting_scan(state, code) do
    case do_waiting_scan(state, code) do
      {:ok, %{"error_code" => 8}} ->
        send(self(), {:continue_waiting_scan, state.abort_ref, code})
        {:ok, state}

      {:ok, %{"data" => data}} when is_map(data) ->
        avatar = data["avatar"] || ""
        display_name = data["display_name"] || ""
        send_event(state, Events.qr_scanned(avatar, display_name))

        state = %{state | state: :waiting_confirm}
        send(self(), {:continue_waiting_confirm, state.abort_ref, code})
        {:ok, state}

      {:ok, %{"error_code" => error_code, "error_message" => message}} ->
        {:error, Error.api(error_code, message)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp waiting_confirm(state, code) do
    case do_waiting_confirm(state, code) do
      {:ok, %{"error_code" => 8}} ->
        send(self(), {:continue_waiting_confirm, state.abort_ref, code})
        {:ok, state}

      {:ok, %{"error_code" => -13}} ->
        cancel_qr_timer(state)
        send_event(state, Events.qr_declined(code))
        {:ok, %{state | state: :aborted}}

      {:ok, %{"error_code" => 0}} ->
        cancel_qr_timer(state)
        finalize_login(state)

      {:ok, %{"error_code" => error_code, "error_message" => message}} ->
        cancel_qr_timer(state)
        {:error, Error.api(error_code, message)}

      {:error, error} ->
        cancel_qr_timer(state)
        {:error, error}
    end
  end

  defp finalize_login(state) do
    wpa_cookies = CookieJar.get_cookie_string(state.cookie_jar_id, "https://wpa.chat.zalo.me/")
    Logger.debug("[LoginQR] Cookies for wpa.chat.zalo.me before fetch_session: #{wpa_cookies}")

    with {:ok, _} <- check_session(state),
         {:ok, user_info} <- get_user_info(state),
         {:ok, uid, name, avatar} <- extract_user_info(user_info, state) do
      cookies = CookieJar.export(state.cookie_jar_id)
      imei = generate_imei()

      # Fetch session by calling getLoginInfo and getServerInfo with the generated IMEI
      # This establishes the IMEI with the server so Manager.login() won't fail with error 102
      case fetch_session(state, cookies, imei) do
        {:ok, session} ->
          event =
            Events.login_complete(
              cookies,
              imei,
              state.user_agent,
              %{uid: uid, name: name, avatar: avatar},
              session
            )

          send_event(state, event)
          {:ok, %{state | state: :complete}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp fetch_session(state, cookies, imei) do
    api_type = 30
    api_version = 645
    language = "vi"

    with {:ok, login_info} <-
           fetch_login_info(state, cookies, imei, api_type, api_version, language),
         {:ok, server_info} <- fetch_server_info(state, cookies, imei, api_type, api_version) do
      session = %Session{
        uid: to_string(login_info["uid"]),
        secret_key: login_info["zpw_enk"],
        zpw_service_map: login_info["zpw_service_map_v3"] || %{},
        ws_endpoints: get_ws_endpoints(server_info),
        api_type: api_type,
        api_version: api_version
      }

      {:ok, session}
    end
  end

  defp fetch_login_info(state, cookies, imei, api_type, api_version, language) do
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
    headers = api_headers(state.user_agent, cookies)

    case Client.get(url, headers) do
      {:ok, %{status: 200, body: body}} ->
        resp = Jason.decode!(body)
        Logger.debug("QR getLoginInfo response: #{inspect(resp)}")

        if resp["error_code"] == 0 do
          decrypted = AesCbc.decrypt_utf8_key(enc_key, resp["data"], :base64)
          Logger.debug("QR decrypted login info: #{inspect(decrypted)}")
          login_data = Jason.decode!(decrypted)

          case login_data do
            %{"error_code" => 0, "data" => data} when is_map(data) ->
              {:ok, data}

            %{"error_code" => code, "error_message" => msg} when code != 0 ->
              {:error, Error.api(code, msg)}

            %{"uid" => _} = data ->
              {:ok, data}

            _ ->
              {:ok, login_data}
          end
        else
          {:error, Error.api(resp["error_code"], resp["error_message"] || "Login info failed")}
        end

      {:ok, %{status: status}} ->
        {:error, Error.api(status, "HTTP #{status}")}

      {:error, reason} ->
        {:error, Error.network("getLoginInfo failed: #{inspect(reason)}")}
    end
  end

  defp fetch_server_info(state, cookies, imei, api_type, api_version) do
    sign_params = %{
      imei: imei,
      type: api_type,
      client_version: api_version,
      computer_name: "Web"
    }

    params = Map.put(sign_params, :signkey, SignKey.generate("getserverinfo", sign_params))

    url =
      HTTP.build_url("https://wpa.chat.zalo.me/api/login/getServerInfo", params,
        api_version: false
      )

    headers = api_headers(state.user_agent, cookies)

    case Client.get(url, headers) do
      {:ok, %{status: 200, body: body}} ->
        resp = Jason.decode!(body)

        if resp["data"] do
          {:ok, resp["data"]}
        else
          {:error,
           Error.api(resp["error_code"], resp["error_message"] || "Failed to get server info")}
        end

      {:ok, %{status: status}} ->
        {:error, Error.api(status, "HTTP #{status}")}

      {:error, reason} ->
        {:error, Error.network("getServerInfo failed: #{inspect(reason)}")}
    end
  end

  defp api_headers(user_agent, cookies) do
    cookie_string =
      cookies
      |> Enum.map(fn %{"name" => name, "value" => value} -> "#{name}=#{value}" end)
      |> Enum.join("; ")

    [
      {"accept", "*/*"},
      {"accept-language", "vi-VN,vi;q=0.9,en-US;q=0.6,en;q=0.5"},
      {"sec-ch-ua", ~s("Chromium";"v="130", "Google Chrome";"v="130", "Not?A_Brand";"v="99")},
      {"sec-ch-ua-mobile", "?0"},
      {"sec-ch-ua-platform", ~s("Windows")},
      {"sec-fetch-dest", "empty"},
      {"sec-fetch-mode", "cors"},
      {"sec-fetch-site", "cross-site"},
      {"referer", "https://chat.zalo.me/"},
      {"user-agent", user_agent},
      {"cookie", cookie_string}
    ]
  end

  defp get_ws_endpoints(server_info) do
    case server_info["zpw_ws"] do
      [%{"endpoint" => _} | _] = ws -> Enum.map(ws, fn e -> e["endpoint"] end)
      [url | _] = ws when is_binary(url) -> ws
      url when is_binary(url) -> [url]
      _ -> ["wss://ws1.chat.zalo.me/ws/v2/webchat/socket"]
    end
  end

  defp extract_user_info(user_info, state) do
    # Try to get uid from response first, then fallback to zpw_sek cookie
    uid_from_response = get_in(user_info, ["data", "uid"])

    uid =
      if uid_from_response,
        do: to_string(uid_from_response),
        else: extract_uid_from_cookies(state)

    case user_info do
      %{"data" => %{"info" => %{"name" => name, "avatar" => avatar}}}
      when is_binary(name) and is_binary(avatar) ->
        {:ok, uid, name, avatar}

      %{"data" => %{"info" => info}} when is_map(info) ->
        {:ok, uid, info["name"] || "", info["avatar"] || ""}

      # Handle case where data has logged/session_chat_valid but no info
      %{"data" => %{"logged" => true}} ->
        {:ok, uid, "", ""}

      # Account requires password confirmation - but we still have session cookies
      # Try to proceed anyway and let the caller decide
      %{"data" => %{"logged" => false, "require_confirm_pwd" => true}} ->
        Logger.warning("userinfo returned require_confirm_pwd=true, attempting to proceed anyway")
        {:ok, uid, "", ""}

      %{"data" => %{"logged" => false}} ->
        {:error, Error.auth("Login failed - session not established")}

      _ ->
        Logger.warning("Unexpected user info structure: #{inspect(user_info)}")
        {:error, Error.api(nil, "Invalid user info response structure")}
    end
  end

  # Extract uid from zpw_sek cookie value
  # Format: {random}.{uid}.{version}.{token}
  # Example: 9aYT.430313233.a0.QgOHdvH0oHQ5...
  defp extract_uid_from_cookies(state) do
    cookies = CookieJar.export(state.cookie_jar_id)

    zpw_sek =
      Enum.find_value(cookies, fn
        %{"name" => "zpw_sek", "value" => value} -> value
        _ -> nil
      end)

    case zpw_sek do
      nil ->
        Logger.warning("zpw_sek cookie not found")
        ""

      value ->
        case String.split(value, ".") do
          [_random, uid, _version | _rest] when byte_size(uid) > 0 ->
            Logger.debug("Extracted uid from zpw_sek: #{uid}")
            uid

          _ ->
            Logger.warning("Could not parse uid from zpw_sek: #{value}")
            ""
        end
    end
  end

  defp load_login_page(state) do
    url = "https://id.zalo.me/account?continue=https%3A%2F%2Fchat.zalo.me%2F"
    headers = browser_headers(state.user_agent, :document)

    case Client.get(url, headers) do
      {:ok, %{status: 200, body: body, headers: resp_headers}} ->
        store_cookies(state, url, resp_headers)

        case extract_version(body) do
          {:ok, version} -> {:ok, version}
          :error -> {:error, Error.api(nil, "Cannot extract login version from page")}
        end

      {:ok, %{status: status}} ->
        {:error, Error.api(status, "Failed to load login page")}

      {:error, reason} ->
        {:error, Error.network("Failed to load login page: #{inspect(reason)}")}
    end
  end

  defp get_login_info(state) do
    url = "https://id.zalo.me/account/logininfo"
    body = URI.encode_query(%{"continue" => "https://zalo.me/pc", "v" => state.version})
    headers = form_headers(state)

    case Client.post(url, body, headers) do
      {:ok, %{status: 200, body: body, headers: resp_headers}} ->
        store_cookies(state, url, resp_headers)
        validate_error_code(body)

      {:ok, %{status: status}} ->
        {:error, Error.api(status, "Failed to get login info")}

      {:error, reason} ->
        {:error, Error.network("Failed to get login info: #{inspect(reason)}")}
    end
  end

  defp verify_client(state) do
    url = "https://id.zalo.me/account/verify-client"

    body =
      URI.encode_query(%{
        "type" => "device",
        "continue" => "https://zalo.me/pc",
        "v" => state.version
      })

    headers = form_headers(state)

    case Client.post(url, body, headers) do
      {:ok, %{status: 200, body: body, headers: resp_headers}} ->
        store_cookies(state, url, resp_headers)
        validate_error_code(body)

      {:ok, %{status: status}} ->
        {:error, Error.api(status, "Failed to verify client")}

      {:error, reason} ->
        {:error, Error.network("Failed to verify client: #{inspect(reason)}")}
    end
  end

  defp generate_qr(state) do
    url = "https://id.zalo.me/account/authen/qr/generate"
    body = URI.encode_query(%{"continue" => "https://zalo.me/pc", "v" => state.version})
    headers = form_headers(state)

    case Client.post(url, body, headers) do
      {:ok, %{status: 200, body: body, headers: resp_headers}} ->
        store_cookies(state, url, resp_headers)

        case Jason.decode(body) do
          {:ok, %{"error_code" => 0, "data" => data}} when is_map(data) ->
            {:ok, data}

          {:ok, %{"error_code" => code, "error_message" => message}} ->
            {:error, Error.api(code, message)}

          {:ok, _} ->
            {:error, Error.api(nil, "Invalid QR generate response")}

          {:error, _} ->
            {:error, Error.api(nil, "Failed to decode QR response")}
        end

      {:ok, %{status: status}} ->
        {:error, Error.api(status, "Failed to generate QR")}

      {:error, reason} ->
        {:error, Error.network("Failed to generate QR: #{inspect(reason)}")}
    end
  end

  defp do_waiting_scan(state, code) do
    url = "https://id.zalo.me/account/authen/qr/waiting-scan"

    body =
      URI.encode_query(%{
        "code" => code,
        "continue" => "https://chat.zalo.me/",
        "v" => state.version
      })

    headers = form_headers(state)

    case Client.post(url, body, headers) do
      {:ok, %{status: 200, body: body, headers: resp_headers}} ->
        store_cookies(state, url, resp_headers)
        Jason.decode(body)

      {:ok, %{status: status}} ->
        {:error, Error.api(status, "Waiting scan failed")}

      {:error, reason} ->
        {:error, Error.network("Waiting scan error: #{inspect(reason)}")}
    end
  end

  defp do_waiting_confirm(state, code) do
    url = "https://id.zalo.me/account/authen/qr/waiting-confirm"

    body =
      URI.encode_query(%{
        "code" => code,
        "continue" => "https://chat.zalo.me/",
        "v" => state.version
      })

    headers = form_headers(state)

    case Client.post(url, body, headers) do
      {:ok, %{status: 200, body: body, headers: resp_headers}} ->
        store_cookies(state, url, resp_headers)
        Jason.decode(body)

      {:ok, %{status: status}} ->
        {:error, Error.api(status, "Waiting confirm failed")}

      {:error, reason} ->
        {:error, Error.network("Waiting confirm error: #{inspect(reason)}")}
    end
  end

  defp check_session(state) do
    url =
      "https://id.zalo.me/account/checksession?continue=https%3A%2F%2Fchat.zalo.me%2Findex.html"

    result = follow_redirects_with_cookies(state, url, 10)

    # Log cookies after check_session completes
    id_cookies = CookieJar.get_cookie_string(state.cookie_jar_id, "https://id.zalo.me/")
    chat_cookies = CookieJar.get_cookie_string(state.cookie_jar_id, "https://chat.zalo.me/")
    wpa_cookies = CookieJar.get_cookie_string(state.cookie_jar_id, "https://wpa.chat.zalo.me/")
    Logger.debug("[LoginQR] After check_session - id.zalo.me: #{id_cookies}")
    Logger.debug("[LoginQR] After check_session - chat.zalo.me: #{chat_cookies}")
    Logger.debug("[LoginQR] After check_session - wpa.chat.zalo.me: #{wpa_cookies}")

    result
  end

  defp follow_redirects_with_cookies(_state, _url, 0) do
    {:error, Error.api(nil, "Too many redirects")}
  end

  defp follow_redirects_with_cookies(state, url, remaining) do
    headers = browser_headers(state.user_agent, :document) |> with_cookies(state, url)

    # Use Req directly with redirect: false to handle manually
    case Req.get(url, headers: headers, redirect: false, decode_body: false) do
      {:ok, %{status: status, headers: resp_headers}} when status in [301, 302, 303, 307, 308] ->
        store_cookies_from_req_headers(state, url, resp_headers)

        case get_location_header(resp_headers) do
          nil ->
            {:error, Error.api(nil, "Redirect without Location header")}

          location ->
            next_url = URI.merge(url, location) |> to_string()
            Logger.debug("redirecting to #{next_url}")
            follow_redirects_with_cookies(state, next_url, remaining - 1)
        end

      {:ok, %{status: 200, headers: resp_headers}} ->
        store_cookies_from_req_headers(state, url, resp_headers)
        {:ok, :session_checked}

      {:ok, %{status: status}} ->
        {:error, Error.api(status, "Check session failed")}

      {:error, reason} ->
        {:error, Error.network("Check session error: #{inspect(reason)}")}
    end
  end

  defp store_cookies_from_req_headers(state, url, headers) do
    uri = URI.parse(url)

    headers
    |> Map.get("set-cookie", [])
    |> List.wrap()
    |> Enum.each(fn value ->
      CookieJar.store(state.cookie_jar_id, uri, value)
    end)
  end

  defp get_location_header(headers) do
    case Map.get(headers, "location") do
      [loc | _] -> loc
      loc when is_binary(loc) -> loc
      _ -> nil
    end
  end

  defp get_user_info(state) do
    url = "https://jr.chat.zalo.me/jr/userinfo"

    # Debug: log all cookies we have
    all_cookies = CookieJar.export(state.cookie_jar_id)
    Logger.debug("All cookies in jar: #{inspect(all_cookies)}")

    headers =
      [
        {"accept", "*/*"},
        {"accept-language", "vi-VN,vi;q=0.9,en-US;q=0.6,en;q=0.5"},
        {"sec-ch-ua", ~s("Chromium";"v="130", "Google Chrome";"v="130", "Not?A_Brand";"v="99")},
        {"sec-ch-ua-mobile", "?0"},
        {"sec-ch-ua-platform", ~s("Windows")},
        {"sec-fetch-dest", "empty"},
        {"sec-fetch-mode", "cors"},
        {"sec-fetch-site", "same-site"},
        {"referer", "https://chat.zalo.me/"},
        {"user-agent", state.user_agent}
      ]
      |> with_cookies(state, "https://jr.chat.zalo.me/jr/userinfo")

    Logger.debug("Headers for userinfo: #{inspect(headers)}")

    case Client.get(url, headers) do
      {:ok, %{status: 200, body: body}} ->
        Logger.debug("Userinfo response body: #{body}")

        case Jason.decode(body) do
          {:ok, %{"error_code" => 0} = response} ->
            Logger.debug("Parsed userinfo response: #{inspect(response)}")
            {:ok, response}

          {:ok, %{"error_code" => code, "error_message" => msg}} ->
            {:error, Error.api(code, msg)}

          {:error, _} ->
            {:error, Error.api(nil, "Failed to decode user info")}
        end

      {:ok, %{status: status}} ->
        {:error, Error.api(status, "Get user info failed")}

      {:error, reason} ->
        {:error, Error.network("Get user info error: #{inspect(reason)}")}
    end
  end

  defp browser_headers(user_agent, :document) do
    [
      {"accept",
       "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"},
      {"accept-language", "vi-VN,vi;q=0.9,en-US;q=0.6,en;q=0.5"},
      {"cache-control", "max-age=0"},
      {"sec-ch-ua", ~s("Chromium";"v="130", "Google Chrome";"v="130", "Not?A_Brand";"v="99")},
      {"sec-ch-ua-mobile", "?0"},
      {"sec-ch-ua-platform", ~s("Windows")},
      {"sec-fetch-dest", "document"},
      {"sec-fetch-mode", "navigate"},
      {"sec-fetch-site", "same-site"},
      {"sec-fetch-user", "?1"},
      {"upgrade-insecure-requests", "1"},
      {"referer", "https://chat.zalo.me/"},
      {"user-agent", user_agent}
    ]
  end

  defp form_headers(state) do
    [
      {"accept", "*/*"},
      {"accept-language", "vi-VN,vi;q=0.9,en-US;q=0.6,en;q=0.5"},
      {"content-type", "application/x-www-form-urlencoded"},
      {"sec-ch-ua", ~s("Chromium";"v="130", "Google Chrome";"v="130", "Not?A_Brand";"v="99")},
      {"sec-ch-ua-mobile", "?0"},
      {"sec-ch-ua-platform", ~s("Windows")},
      {"sec-fetch-dest", "empty"},
      {"sec-fetch-mode", "cors"},
      {"sec-fetch-site", "same-origin"},
      {"referer", "https://id.zalo.me/account?continue=https%3A%2F%2Fzalo.me%2Fpc"},
      {"user-agent", state.user_agent}
    ]
    |> with_cookies(state)
  end

  defp with_cookies(headers, state, url \\ "https://id.zalo.me/") do
    cookie_string = CookieJar.get_cookie_string(state.cookie_jar_id, url)

    if cookie_string != "" do
      [{"cookie", cookie_string} | headers]
    else
      headers
    end
  end

  defp store_cookies(state, url, headers) do
    uri = URI.parse(url)

    headers
    |> Enum.filter(fn {name, _} -> String.downcase(name) == "set-cookie" end)
    |> Enum.each(fn {_, value} ->
      CookieJar.store(state.cookie_jar_id, uri, value)
    end)
  end

  defp cancel_qr_timer(%{qr_timer: nil}), do: :ok

  defp cancel_qr_timer(%{qr_timer: timer}) do
    Process.cancel_timer(timer)
    :ok
  end

  defp send_event(%{callback_pid: nil}, _event), do: :ok
  defp send_event(%{callback_pid: pid}, event), do: send(pid, {:zca_qr_login, event})

  defp validate_error_code(body) do
    case Jason.decode(body) do
      {:ok, %{"error_code" => 0}} -> :ok
      {:ok, %{"error_code" => code, "error_message" => msg}} -> {:error, Error.api(code, msg)}
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  defp strip_data_uri(image) when is_binary(image) do
    String.replace(image, ~r/^data:image\/png;base64,/, "")
  end

  defp strip_data_uri(image), do: image

  defp generate_imei do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp default_user_agent do
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
  end
end
