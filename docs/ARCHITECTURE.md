# ZcaEx Architecture

ZcaEx manages multiple Zalo accounts through a supervision tree that isolates each account's state and credentials.

## Supervision Tree

```
Application
├── Registry (ZcaEx.Registry)
├── Events (:pg process group scope)
└── DynamicSupervisor (ZcaEx.AccountSupervisor)
    └── Account.Supervisor (per account, one_for_all)
        ├── CookieJar.Jar (ETS-backed cookie storage)
        ├── Account.Manager (GenServer: credentials, session, state)
        ├── WS.Connection (WebSocket lifecycle, starts disconnected)
        └── Account.Runtime (orchestrates login/WS lifecycle)
```

Each account runs in isolation. Failures in one account do not affect others.

## Core Modules

| Module | Purpose |
|--------|---------|
| `ZcaEx` | Public API facade |
| `ZcaEx.Account` | Account health management (health checks, recovery, reset) |
| `Account.Manager` | Per-account state machine (login, session) |
| `Account.Runtime` | "Always-on" orchestrator (auto-login, auto-connect WS) |
| `Account.Credentials` | Immutable credential struct (IMEI, cookies, user-agent) |
| `Account.Session` | Active session data (UID, secret key, service URLs) |
| `WS.Connection` | WebSocket lifecycle and message dispatch |
| `Events` | Pub/sub via `:pg` process groups |
| `Api.Endpoints.*` | REST API wrappers |

## Data Flow

```
User Code
    │
    ▼
ZcaEx.add_account/2 (with runtime opts)
    │
    ▼
Account.Supervisor starts all children
    │
    ├─► CookieJar (stores cookies)
    ├─► Manager (idle, has credentials)
    ├─► WS.Connection (disconnected)
    └─► Runtime (orchestrates lifecycle)
            │
            ▼
        auto_login ──► Manager.login/1 ──► HTTP APIs
            │
            ▼
        auto_connect ──► WS.Connection.connect/3 ──► Zalo WS
            │
            ▼
        Events.Dispatcher ───► :pg groups ───► Subscribers
                                    │
                                    ▼
                           PhoenixPubSub Adapter (optional)
```

## Account.Runtime State Machine

```
                    ┌──────────────────────────────────────┐
                    │                                      │
                    ▼                                      │
    ┌─────────► idle ◄─────────────────┐                   │
    │             │                    │                   │
    │             │ auto_login=true    │                   │
    │             ▼                    │                   │
    │       logging_in                 │                   │
    │         │      │                 │                   │
    │   success│     │error            │                   │
    │         │      ▼                 │                   │
    │         │  login_backoff ────────┤ retry
    │         │                        │
    │         ▼                        │
    │    logged_in ◄───────────────────┤
    │         │                        │
    │         │ ws.auto_connect=true   │
    │         ▼                        │
    │   ws_connecting                  │
    │         │                        │
    │         │ :ready event           │
    │         ▼                        │
    │     ws_ready                     │
    │         │                        │
    │         │ session_expired        │
    └─────────┴────────────────────────┘

    stopped (sticky - ignores all events)
```

## What's Started Automatically

| Component | Started By | When | Default Behavior |
|-----------|------------|------|------------------|
| Registry, Events, AccountSupervisor | Application | App boot | — |
| Account.Supervisor | `ZcaEx.add_account/2` | Account creation | — |
| CookieJar, Manager, WS.Connection, Runtime | Account.Supervisor | Account creation | — |
| **Login** | Runtime | Immediately | `auto_login: true` |
| **WS Connect** | Runtime | After login success | `ws.auto_connect: true` |

## Configuration Options

Pass runtime options to `ZcaEx.add_account/2`:

```elixir
ZcaEx.add_account("acc123",
  imei: "...",
  cookies: "...",
  user_agent: "...",
  runtime: [
    auto_login: true,           # Auto-login on start (default: true)
    ws: [
      auto_connect: true,       # Auto-connect WS after login (default: true)
      reconnect: true           # WS auto-reconnect on disconnect (default: true)
    ],
    login: [
      retry: [
        enabled: true,          # Retry login on failure (default: true)
        min_ms: 1000,           # Initial backoff delay
        max_ms: 30_000,         # Max backoff delay
        factor: 2.0,            # Exponential factor
        jitter: 0.2             # Jitter factor (0-1)
      ]
    ]
  ]
)
```

## Runtime Management APIs

```elixir
# Get account status
{:ok, %{phase: :ws_ready, config: config}} = ZcaEx.account_status("acc123")

# Reconfigure at runtime
ZcaEx.configure_account("acc123", ws: [auto_connect: false])

# Force reconnect attempt
ZcaEx.reconnect("acc123")

# Pause auto-features (account stays up, just stops auto-login/connect)
ZcaEx.pause_account("acc123")
```

## Supervision Strategy: `:one_for_all`

The account supervisor uses `:one_for_all`, meaning if **any** child crashes, **all** children restart together. This ensures a coherent auth/session state:

- CookieJar, Manager login/session, and WS auth are tightly coupled
- If CookieJar dies, keeping Manager/WS alive leaves you in "connected-but-unusable" state
- Full restart guarantees all processes have consistent state

> **Trade-off**: If WS.Connection crashes frequently (network flaps), it restarts CookieJar/Manager too. This is acceptable if you have higher-level reconnection logic.

## Account Health Management

`ZcaEx.Account` provides APIs for checking and recovering account health:

```elixir
# Check if all account processes are alive
case ZcaEx.Account.health("acc123") do
  :ok -> # All healthy
  {:error, :not_found} -> # Account not started
  {:error, :partial_start} -> # Some processes missing (needs reset)
  {:error, :cookie_jar_dead} -> # CookieJar registered but not alive
  {:error, :manager_dead} -> # Manager registered but not alive
  {:error, :ws_dead} -> # WS.Connection registered but not alive
end

# Idempotent "make it good" - checks health, resets if unhealthy, connects WS
{:ok, session} = ZcaEx.Account.ensure_connected("acc123", credentials, session)

# Hard restart of entire account subtree
:ok = ZcaEx.Account.reset("acc123")
```

### When to Use

- **`health/1`**: Before operations, check if account is in a good state
- **`ensure_connected/3`**: Recover from failures (e.g., after "session dead" errors during API calls)
- **`reset/1`**: Force full restart when account is in unknown/bad state
