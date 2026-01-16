# Authentication Flow

ZcaEx supports two authentication paths: direct login with existing credentials and QR-based login for new sessions.

## Direct Login (Existing Credentials)

Use this when you already have IMEI, cookies, and user-agent from a previous session.

```elixir
# 1. Add account with credentials
{:ok, _pid} = ZcaEx.add_account("my_account",
  imei: "device_imei",
  cookies: "cookie_string_or_list",
  user_agent: "Mozilla/5.0 ..."
)

# 2. Login to get session
{:ok, session} = ZcaEx.login("my_account")

# 3. Now ready to use API endpoints
```

### Login Flow

```
add_account(id, opts)
    │
    ▼
Credentials.new/1 ──► validates required fields
    │
    ▼
Account.Supervisor starts
    │
    ├─► CookieJar.Jar (stores cookies in ETS)
    └─► Account.Manager (idle state)

login(id)
    │
    ▼
Manager.do_login/1
    │
    ├─► Import cookies to CookieJar
    │
    ├─► GET /api/login/getLoginInfo
    │       • ParamsEncryptor derives encrypt_key
    │       • Signs params with SignKey
    │       • Encrypts body with AES-CBC (UTF-8 key)
    │       • Returns UID and zpw_enk (secret key)
    │
    ├─► GET /api/login/getServerInfo
    │       • Returns WebSocket endpoints
    │       • Returns service URL maps
    │
    └─► Creates Session struct
            • UID, secret_key, service URLs
```

## QR Login (New Session)

Use `Api.LoginQR` to acquire fresh credentials by scanning a QR code with the Zalo mobile app.

### Usage

```elixir
# 1. Start QR login flow
{:ok, qr_pid} = ZcaEx.Api.LoginQR.start(self(), user_agent: "Mozilla/5.0 ...")

# 2. Handle events
def handle_info({:zca_qr_login, event}, state) do
  case event do
    %{type: :qr_generated, code: code, image: base64_image} ->
      # Display QR code to user (base64_image is PNG data)
      {:noreply, state}

    %{type: :qr_scanned} ->
      # User scanned, waiting for confirmation
      {:noreply, state}

    %{type: :login_complete, cookies: cookies, imei: imei, user_agent: ua, user_info: info} ->
      # Success! Save credentials and create account
      {:ok, _} = ZcaEx.add_account("my_account",
        imei: imei,
        cookies: cookies,
        user_agent: ua
      )
      {:noreply, state}

    %{type: :qr_expired} ->
      # QR expired, call LoginQR.retry(qr_pid)
      {:noreply, state}

    %{type: :error, error: error} ->
      # Handle error
      {:noreply, state}
  end
end

# 3. Abort if needed
ZcaEx.Api.LoginQR.abort(qr_pid)

# 4. Retry with fresh QR
ZcaEx.Api.LoginQR.retry(qr_pid)
```

### QR Flow Sequence

```
LoginQR.start(callback_pid)
    │
    ▼
1. GET id.zalo.me (extract JS version)
    │
    ▼
2. POST /account/authen/qr/generate
    │   Returns: QR code + base64 image
    │
    ▼
   ──► {:zca_qr_login, %{type: :qr_generated, code: ..., image: ...}}

3. Long-poll /waiting-scan
    │   User scans QR with phone
    │
    ▼
   ──► {:zca_qr_login, %{type: :qr_scanned}}

4. Long-poll /waiting-confirm
    │   User confirms on phone
    │
    ▼
5. GET /account/checksession (handles 302 redirects)
    │   Finalizes cookies
    │
    ▼
6. GET jr.chat.zalo.me/jr/userinfo
    │   Fetch user profile
    │
    ▼
   ──► {:zca_qr_login, %{type: :login_complete, cookies: ..., imei: ..., user_info: ...}}
```

## Cookie Management

### Cookie Formats

The `cookies` option accepts multiple formats:

```elixir
# String format (from browser)
cookies: "_zlang=vi; zpw_sek=abc123; ..."

# List of maps
cookies: [
  %{name: "_zlang", value: "vi", domain: ".zalo.me"},
  %{name: "zpw_sek", value: "abc123", domain: ".chat.zalo.me"}
]

# Map format
cookies: %{"_zlang" => "vi", "zpw_sek" => "abc123"}
```

### Persistence

Export cookies to persist sessions across restarts:

```elixir
# Export cookies
cookies = ZcaEx.CookieJar.export("my_account")

# Store in database/file...

# Later, restore
{:ok, _} = ZcaEx.add_account("my_account",
  imei: stored_imei,
  cookies: cookies,
  user_agent: stored_ua
)
```

## Configuration Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `imei` | Yes | — | Device IMEI |
| `cookies` | Yes | — | Authentication cookies |
| `user_agent` | Yes | — | Browser user-agent string |
| `api_type` | No | 30 | API type identifier |
| `api_version` | No | 637 | API version |
| `language` | No | "vi" | Language code |
