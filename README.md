# ZcaEx

An Elixir port of [zca-js](https://github.com/RFS-ADRENO/zca-js) — an unofficial Zalo API client.

> ⚠️ **Disclaimer**: This is an unofficial library and is not affiliated with Zalo/VNG Corporation.

## Features

- **Multi-account support** — Manage multiple Zalo accounts via isolated per-account GenServers
- **WebSocket events** — Real-time messages, typing indicators, reactions, and presence
- **Phoenix integration** — Built-in Phoenix.PubSub adapter for LiveView applications
- **Lightweight pub/sub** — `:pg`-based event system with no external dependencies
- **Automatic reconnection** — Resilient WebSocket with exponential backoff

## Installation

Add `zca_ex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zca_ex, "~> 0.1.0"},
    {:phoenix_pubsub, "~> 2.1"}  # optional, for Phoenix integration
  ]
end
```

## Quick Start

```elixir
# 1. Add account
{:ok, _} = ZcaEx.add_account("my_account",
  imei: "your_imei",
  cookies: "your_cookies",
  user_agent: "Mozilla/5.0 ..."
)

# 2. Login
{:ok, session} = ZcaEx.login("my_account")

# 3. Start WebSocket (required for real-time events)
{:ok, ws} = ZcaEx.WS.Connection.start_link(account_id: "my_account", session: session)
:ok = ZcaEx.WS.Connection.connect(ws)

# 4. Subscribe to events
ZcaEx.Events.subscribe("zca:my_account:message")

# 5. Handle events in your process
def handle_info({:zca_event, _topic, event}, state) do
  IO.inspect(event)
  {:noreply, state}
end

# 6. Send messages via API
alias ZcaEx.Api.Endpoints.SendMessage
credentials = ZcaEx.Account.Manager.get_credentials("my_account")
SendMessage.send("Hello!", thread_id, :user, session, credentials)
```

## Documentation

See the [docs/](docs/) folder for detailed documentation:

- [Architecture](docs/ARCHITECTURE.md) — Supervision tree and data flow
- [Authentication](docs/AUTHENTICATION.md) — Direct login and QR-based flows
- [WebSocket](docs/WEBSOCKET.md) — Real-time connection and message routing
- [Events](docs/EVENTS.md) — Pub/sub system and Phoenix integration
- [Cryptography](docs/CRYPTOGRAPHY.md) — AES encryption and request signing
- [API Endpoints](docs/API_ENDPOINTS.md) — REST API wrappers
- [Error Handling](docs/ERROR_HANDLING.md) — Structured error types

## Configuration

```elixir
ZcaEx.add_account("account_id",
  imei: "device_imei",           # required
  cookies: "cookie_string",      # required
  user_agent: "Mozilla/5.0...",  # required
  api_type: 30,                  # optional (default: 30)
  api_version: 637,              # optional (default: 637)
  language: "vi"                 # optional (default: "vi")
)
```

## License

MIT License — see [LICENSE](LICENSE) for details.
