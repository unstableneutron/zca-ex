# Event System

ZcaEx uses Erlang's `:pg` (process groups) for lightweight pub/sub with no external dependencies.

## Event Flow

```
WS.Connection receives frame
    │
    ▼
Events.Dispatcher.dispatch(account_id, event_type, payload)
    │
    ▼
Topic.build(account_id, event_type)
    │   e.g., "zca:my_account:message"
    │
    ▼
Events.broadcast(topic, event)
    │
    ▼
:pg sends {:zca_event, topic, event} to all subscribers
    │
    ├─► Your GenServer/LiveView process
    │
    └─► PhoenixPubSub Adapter (optional)
            │
            ▼
        Phoenix.PubSub.broadcast
```

## Topic Format

```
zca:<account_id>:<event_type>
zca:<account_id>:<event_type>:<sub_type>
```

Examples:
- `zca:acc123:message`
- `zca:acc123:message:group`
- `zca:acc123:connected`

## Event Types

| Type | Description |
|------|-------------|
| `:connected` | WebSocket connection established |
| `:disconnected` | WebSocket connection lost |
| `:cipher_key` | Encryption key received (connection ready) |
| `:message` | New message (user or group) |
| `:old_messages` | Historical messages loaded |
| `:typing` | Typing indicator |
| `:reaction` | Reaction added/removed |
| `:old_reactions` | Historical reactions loaded |
| `:seen_delivered` | Read receipt (seen + delivered combined) |
| `:control` | Control events (uploads, group/friend changes) |
| `:duplicate` | Duplicate connection detected |

> **Note:** Seen and delivered events arrive as a single `:seen_delivered` type, not separate events.

## Usage

```elixir
# Subscribe
ZcaEx.Events.subscribe("zca:my_account:message")

# Handle in GenServer
def handle_info({:zca_event, topic, event}, state) do
  # process event
  {:noreply, state}
end

# Unsubscribe
ZcaEx.Events.unsubscribe("zca:my_account:message")
```

## Phoenix Integration

The `PhoenixPubSub` adapter bridges `:pg` events to Phoenix.PubSub:

```elixir
# In your supervision tree
{ZcaEx.Adapters.PhoenixPubSub,
  pubsub: MyApp.PubSub,
  accounts: ["account1", "account2"]}

# In LiveView
Phoenix.PubSub.subscribe(MyApp.PubSub, "zca:account1:message")
```

Events arrive as `{:zca_event, topic, payload}` in both systems.

## Complete Example

```elixir
defmodule MyApp.ZaloHandler do
  use GenServer

  def start_link(account_id) do
    GenServer.start_link(__MODULE__, account_id)
  end

  def init(account_id) do
    # Subscribe to events
    ZcaEx.Events.subscribe("zca:#{account_id}:message")
    ZcaEx.Events.subscribe("zca:#{account_id}:typing")
    ZcaEx.Events.subscribe("zca:#{account_id}:connected")

    {:ok, %{account_id: account_id}}
  end

  def handle_info({:zca_event, _topic, {:message, _account, msg}}, state) do
    IO.inspect(msg, label: "New message")
    {:noreply, state}
  end

  def handle_info({:zca_event, _topic, {:connected, _account, _}}, state) do
    IO.puts("WebSocket connected!")
    {:noreply, state}
  end

  def handle_info({:zca_event, _topic, _event}, state) do
    {:noreply, state}
  end
end
```
