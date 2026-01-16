# ZcaEx Documentation

Technical documentation for the ZcaEx Elixir Zalo API client.

## Contents

| Document | Description |
|----------|-------------|
| [Architecture](ARCHITECTURE.md) | Supervision tree, core modules, data flow |
| [Authentication](AUTHENTICATION.md) | Login flows: direct credentials and QR-based |
| [WebSocket](WEBSOCKET.md) | Real-time connection, message routing, retry policy |
| [Events](EVENTS.md) | Pub/sub system, topics, Phoenix integration |
| [Cryptography](CRYPTOGRAPHY.md) | AES-CBC/GCM, request signing, key derivation |
| [API Endpoints](API_ENDPOINTS.md) | REST API wrappers for messaging, users, groups |
| [Error Handling](ERROR_HANDLING.md) | Structured errors, categories, retryability |

## Quick Start

```elixir
# 1. Add account
{:ok, _} = ZcaEx.add_account("my_account",
  imei: "device_imei",
  cookies: "cookie_string",
  user_agent: "Mozilla/5.0 ..."
)

# 2. Login
{:ok, session} = ZcaEx.login("my_account")

# 3. Start WebSocket (required for real-time events)
{:ok, ws} = ZcaEx.WS.Connection.start_link(account_id: "my_account", session: session)
:ok = ZcaEx.WS.Connection.connect(ws)

# 4. Subscribe to events
ZcaEx.Events.subscribe("zca:my_account:message")

# 5. Use API endpoints
alias ZcaEx.Api.Endpoints.SendMessage
SendMessage.send("Hello!", thread_id, :user, session, credentials)
```

## Module Map

```
lib/zca_ex/
├── account/          # Per-account management
│   ├── credentials.ex    # Immutable credential struct
│   ├── manager.ex        # State machine (login, session)
│   ├── session.ex        # Active session data
│   └── supervisor.ex     # Per-account supervisor
├── adapters/         # Phoenix.PubSub bridge
├── api/              # HTTP API layer
│   ├── endpoints/        # 100+ REST endpoints
│   ├── factory.ex        # Endpoint macro
│   ├── login_qr.ex       # QR login flow
│   ├── response.ex       # Response decryption
│   └── url.ex            # URL construction
├── cookie_jar/       # Cookie storage (ETS)
├── crypto/           # Encryption
│   ├── aes_cbc.ex        # Request/response encryption
│   ├── aes_gcm.ex        # WebSocket decryption
│   ├── params_encryptor.ex # Login key derivation
│   └── sign_key.ex       # Request signing
├── events/           # :pg pub/sub
│   ├── dispatcher.ex     # Event broadcasting
│   ├── events.ex         # Subscribe/broadcast API
│   └── topic.ex          # Topic construction
├── http/             # HTTP client
│   ├── account_client.ex # Per-account client
│   ├── client.ex         # Low-level Req wrapper
│   └── middleware/       # Cookie injection
└── ws/               # WebSocket
    ├── connection.ex     # Connection lifecycle
    ├── frame.ex          # Binary protocol
    ├── retry_policy.ex   # Reconnection logic
    └── router.ex         # cmd → event type mapping
```

## Key Concepts

1. **Accounts are isolated** — Each account has its own supervisor, cookie jar, and state
2. **WebSocket is opt-in** — Start it explicitly after login to receive events
3. **Two AES-CBC keys** — Login uses `encrypt_key`, API calls use `session.secret_key`
4. **Events use :pg** — Lightweight pub/sub with optional Phoenix.PubSub bridge
