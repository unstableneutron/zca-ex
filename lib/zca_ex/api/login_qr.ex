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

  Events are sent to a callback process as the flow progresses.
  """

  use GenServer

  require Logger

  alias ZcaEx.Api.LoginQR.Events
  alias ZcaEx.CookieJar.Jar, as: CookieJar
  alias ZcaEx.Error
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
    state = %{state | state: :initializing, qr_code: nil, qr_timer: nil, abort_ref: abort_ref, cookie_jar_id: new_cookie_jar_id}
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
    with {:ok, _} <- check_session(state),
         {:ok, user_info} <- get_user_info(state),
         {:ok, uid, name, avatar} <- extract_user_info(user_info) do
      cookies = CookieJar.export(state.cookie_jar_id)

      event =
        Events.login_complete(
          cookies,
          generate_imei(),
          state.user_agent,
          %{uid: uid, name: name, avatar: avatar}
        )

      send_event(state, event)
      {:ok, %{state | state: :complete}}
    end
  end

  defp extract_user_info(user_info) do
    case user_info do
      %{"data" => %{"uid" => uid, "info" => %{"name" => name, "avatar" => avatar}}}
      when is_binary(name) and is_binary(avatar) ->
        {:ok, to_string(uid), name, avatar}

      %{"data" => %{"uid" => uid, "info" => info}} when is_map(info) ->
        {:ok, to_string(uid), info["name"] || "", info["avatar"] || ""}

      %{"data" => %{"info" => %{"name" => name, "avatar" => avatar}}}
      when is_binary(name) and is_binary(avatar) ->
        # Fallback: try to get uid from cookies if not in response
        {:ok, "", name, avatar}

      %{"data" => %{"info" => info}} when is_map(info) ->
        {:ok, "", info["name"] || "", info["avatar"] || ""}

      # Handle case where data has logged/session_chat_valid but no info
      %{"data" => %{"uid" => uid, "logged" => true}} ->
        {:ok, to_string(uid), "", ""}

      %{"data" => %{"logged" => true}} ->
        {:ok, "", "", ""}

      # Account requires password confirmation - but we still have session cookies
      # Try to proceed anyway and let the caller decide
      %{"data" => %{"uid" => uid, "logged" => false, "require_confirm_pwd" => true}} ->
        Logger.warning("userinfo returned require_confirm_pwd=true, attempting to proceed anyway")
        {:ok, to_string(uid), "", ""}

      %{"data" => %{"logged" => false, "require_confirm_pwd" => true}} ->
        Logger.warning("userinfo returned require_confirm_pwd=true, attempting to proceed anyway")
        {:ok, "", "", ""}

      %{"data" => %{"logged" => false}} ->
        {:error, Error.auth("Login failed - session not established")}

      _ ->
        Logger.warning("Unexpected user info structure: #{inspect(user_info)}")
        {:error, Error.api(nil, "Invalid user info response structure")}
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
    url = "https://id.zalo.me/account/checksession?continue=https%3A%2F%2Fchat.zalo.me%2Findex.html"
    follow_redirects_with_cookies(state, url, 10)
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
        case Jason.decode(body) do
          {:ok, %{"error_code" => 0} = response} -> {:ok, response}
          {:ok, %{"error_code" => code, "error_message" => msg}} -> {:error, Error.api(code, msg)}
          {:error, _} -> {:error, Error.api(nil, "Failed to decode user info")}
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
