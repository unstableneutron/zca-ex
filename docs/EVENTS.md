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
| `:message` | New message (user or group) - `Message` struct |
| `:undo` | Message deleted/undone - `Undo` struct |
| `:old_messages` | Historical messages loaded |
| `:typing` | Typing indicator (includes thread_type) - `Typing` struct |
| `:reaction` | Reaction added/removed - `Reaction` struct |
| `:old_reactions` | Historical reactions loaded |
| `:delivered` | Message delivered to recipient - `DeliveredMessage` struct |
| `:seen` | Message seen by recipient - `SeenMessage` struct |
| `:control` | Control events (uploads, group/friend changes) |
| `:duplicate` | Duplicate connection detected |

## Event Payloads

Events are dispatched with model structs (not raw maps). The event tuple format is:

```elixir
{:zca_event, topic, {event_type, account_id, model_struct}}
```

### Model Structs

| Model | Fields |
|-------|--------|
| `Message` | `msg_id`, `cli_msg_id`, `msg_type`, `uid_from`, `id_to`, `content`, `ts`, `ttl`, `thread_id`, `thread_type`, `is_self`, `quote`, `mentions` |
| `Undo` | `action_id`, `msg_id`, `cli_msg_id`, `msg_type`, `uid_from`, `id_to`, `d_name`, `ts`, `status`, `content`, `ttl`, `thread_id`, `thread_type`, `is_self`, `undo_msg_id` |
| `Typing` | `uid`, `ts`, `is_pc`, `thread_id`, `thread_type`, `is_self` |
| `Reaction` | `action_id`, `msg_id`, `cli_msg_id`, `msg_type`, `uid_from`, `id_to`, `d_name`, `content`, `ts`, `ttl`, `thread_id`, `thread_type`, `is_self` |
| `SeenMessage` | `msg_id`, `real_msg_id`, `id_to`, `group_id`, `thread_id`, `thread_type`, `is_self`, `seen_uids` |
| `DeliveredMessage` | `msg_id`, `real_msg_id`, `group_id`, `thread_id`, `thread_type`, `is_self`, `seen`, `delivered_uids`, `seen_uids`, `ts` |

All models normalize `uid_from`/`id_to` (convert `"0"` to actual user ID) and set `is_self` based on whether the event originated from the current user.

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

  # Handle new message (msg is a Message struct)
  def handle_info({:zca_event, _topic, {:message, _account, %ZcaEx.Model.Message{} = msg}}, state) do
    IO.puts("New message from #{msg.uid_from}: #{msg.content}")
    {:noreply, state}
  end

  # Handle message deletion (undo is an Undo struct)
  def handle_info({:zca_event, _topic, {:undo, _account, %ZcaEx.Model.Undo{} = undo}}, state) do
    IO.puts("Message #{undo.undo_msg_id} was deleted")
    {:noreply, state}
  end

  # Handle typing indicator (typing is a Typing struct)
  def handle_info({:zca_event, _topic, {:typing, _account, %ZcaEx.Model.Typing{} = typing}}, state) do
    IO.puts("User #{typing.uid} is typing in #{typing.thread_type}")
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
