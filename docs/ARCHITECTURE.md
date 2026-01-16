# ZcaEx Architecture

ZcaEx manages multiple Zalo accounts through a supervision tree that isolates each account's state and credentials.

## Supervision Tree

```
Application
├── Registry (ZcaEx.Registry)
├── Events (:pg process group scope)
└── DynamicSupervisor (ZcaEx.AccountSupervisor)
    └── Account.Supervisor (per account)
        ├── CookieJar.Jar (ETS-backed cookie storage)
        └── Account.Manager (GenServer: credentials, session, state)
```

Each account runs in isolation. Failures in one account do not affect others.

> **Note:** `WS.Connection` is **not** started automatically. You must start it explicitly to receive real-time events. See [WebSocket](WEBSOCKET.md) for details.

## Core Modules

| Module | Purpose |
|--------|---------|
| `ZcaEx` | Public API facade |
| `Account.Manager` | Per-account state machine (login, session) |
| `Account.Credentials` | Immutable credential struct (IMEI, cookies, user-agent) |
| `Account.Session` | Active session data (UID, secret key, service URLs) |
| `WS.Connection` | WebSocket lifecycle and message dispatch (started separately) |
| `Events` | Pub/sub via `:pg` process groups |
| `Api.Endpoints.*` | REST API wrappers |

## Data Flow

```
User Code
    │
    ▼
ZcaEx.add_account/login
    │
    ▼
Account.Manager ─────────────────► HTTP APIs
    │                                 │
    │                                 ▼
    │                           Api.Endpoints.*
    │                                 │
    ▼                                 ▼
WS.Connection ◄──────────────── Session data
(started by user)
    │
    ▼
Events.Dispatcher ───► :pg groups ───► Subscribers
                            │
                            ▼
                   PhoenixPubSub Adapter (optional)
```

## What's Started Automatically vs Manually

| Component | Started By | When |
|-----------|------------|------|
| Registry, Events, AccountSupervisor | Application | App boot |
| Account.Supervisor | `ZcaEx.add_account/2` | Account creation |
| CookieJar, Manager | Account.Supervisor | Account creation |
| Session | `ZcaEx.login/1` | Login call |
| **WS.Connection** | **You** | After login, when you need events |
