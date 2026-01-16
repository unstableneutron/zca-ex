# WebSocket System

The WebSocket connection receives real-time events from Zalo servers: messages, typing indicators, reactions, and presence updates.

> **Important:** WebSocket is **not** started automatically. You must start it after login to receive events.

## Starting the WebSocket

```elixir
# 1. Login first
{:ok, session} = ZcaEx.login("my_account")

# 2. Start WebSocket connection
{:ok, ws_pid} = ZcaEx.WS.Connection.start_link(
  account_id: "my_account",
  session: session
)

# 3. Connect (with auto-reconnect)
:ok = ZcaEx.WS.Connection.connect(ws_pid)

# 4. Subscribe to events
ZcaEx.Events.subscribe("zca:my_account:message")
```

## Connection Lifecycle

The connection progresses through states: `disconnected → connecting → connected → ready`.

Events only decrypt after receiving `cipher_key` (the connection becomes `:ready`).

```
start_link(opts)
    │
    ▼
connect/1
    │   HTTP upgrade via Mint.WebSocket
    │
    ▼
connected (HTTP 101 OK)
    │
    ▼
receive cmd=1, subCmd=1
    │   cipher_key frame arrives
    │
    ▼
ready (can decrypt events)
    │
    ├─► Frame received
    │       │
    │       ▼
    │   Frame.decode/1 (4-byte header + JSON)
    │       │
    │       ▼
    │   Router.route/1 (cmd/subCmd → event type)
    │       │
    │       ▼
    │   AES-GCM decrypt (if needed)
    │       │
    │       ▼
    │   Dispatcher.dispatch/3 → Events.broadcast/2
    │
    └─► Connection lost → RetryPolicy triggers reconnect
```

## Message Routing

| cmd | subCmd | Event Type | Thread Type |
|-----|--------|------------|-------------|
| 1 | 1 | `:cipher_key` | — |
| 2 | 1 | `:ping` | — |
| 501 | 0 | `:message` | `:user` |
| 521 | 0 | `:message` | `:group` |
| 510 | 1 | `:old_messages` | `:user` |
| 511 | 1 | `:old_messages` | `:group` |
| 502 | 0 | `:seen_delivered` | `:user` |
| 522 | 0 | `:seen_delivered` | `:group` |
| 601 | 0 | `:control` | — |
| 602 | 0 | `:typing` | — |
| 610 | 1 | `:old_reactions` | `:user` |
| 611 | 1 | `:old_reactions` | `:group` |
| 612 | * | `:reaction` | — |
| 3000 | 0 | `:duplicate` | — |

Control events (cmd=601) contain sub-types parsed by `ControlParser`: uploads, group changes, friend events.

## Retry Policy

`WS.RetryPolicy` implements exponential backoff with jitter:

- Base delay: 100ms
- Max delay: 30 seconds
- Jitter: ±25%
- Max attempts per endpoint: 3
- Max total attempts: 15
- Rotates through available WebSocket endpoints on failure

## Frame Format

```
┌──────────────┬──────────────────────────────────┐
│ Header (4B)  │ JSON Payload                     │
├──────────────┼──────────────────────────────────┤
│ cmd (2B)     │ { "data": ..., "subCmd": ... }   │
│ length (2B)  │                                  │
└──────────────┴──────────────────────────────────┘
```

Encrypted payloads use AES-GCM: 16B IV + 16B AAD + ciphertext + 16B tag.
