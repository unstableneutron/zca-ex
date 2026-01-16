# ZcaEx

An Elixir port of [zca-js](https://github.com/RFS-ADRENO/zca-js) - an unofficial Zalo API client.

> ⚠️ **Disclaimer**: This is an unofficial library and is not affiliated with Zalo/VNG Corporation.

## Features

- **Multi-account support** - Manage multiple Zalo accounts simultaneously via per-account GenServers
- **WebSocket events** - Real-time message, typing, reaction, and presence events
- **Phoenix integration** - Built-in Phoenix.PubSub adapter for LiveView applications
- **Process group pub/sub** - Lightweight `:pg`-based event system with no external dependencies
- **Telemetry instrumentation** - Observable metrics for monitoring
- **Automatic reconnection** - Resilient WebSocket connections with configurable retry policies

## Installation

Add `zca_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zca_ex, "~> 0.1.0"},
    # Optional: for Phoenix integration
    {:phoenix_pubsub, "~> 2.1"}
  ]
end
```

## Quick Start

```elixir
# Add an account
{:ok, _pid} = ZcaEx.add_account("my_account", [
  imei: "your_imei",
  cookies: "your_cookies_string",
  user_agent: "Mozilla/5.0 ..."
])

# Login
{:ok, session} = ZcaEx.login("my_account")

# Subscribe to events
ZcaEx.Events.subscribe("zca:my_account:message")

# Handle events in your process
def handle_info({:zca_event, topic, event}, state) do
  IO.inspect(event, label: "Received event on #{topic}")
  {:noreply, state}
end

# Send a message
alias ZcaEx.Api.Endpoints.SendMessage

session = ZcaEx.get_session("my_account")
SendMessage.send("Hello!", thread_id, :user, session, credentials)

# List all accounts
ZcaEx.list_accounts()

# Remove an account
ZcaEx.remove_account("my_account")
```

## Phoenix Integration

### Setup Phoenix.PubSub Adapter

Add the adapter to your supervision tree in `application.ex`:

```elixir
children = [
  # Start Phoenix.PubSub first
  {Phoenix.PubSub, name: MyApp.PubSub},
  
  # Start ZcaEx events
  {ZcaEx.Events, []},
  
  # Bridge ZcaEx events to Phoenix.PubSub
  {ZcaEx.Adapters.PhoenixPubSub,
    pubsub: MyApp.PubSub,
    accounts: ["account1", "account2"]}
]
```

### LiveView Integration

```elixir
defmodule MyAppWeb.ChatLive do
  use Phoenix.LiveView
  
  alias ZcaEx.Events.Topic
  
  @pubsub MyApp.PubSub
  @account_id "my_account"
  
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to specific event types
      Phoenix.PubSub.subscribe(@pubsub, Topic.build(@account_id, :message))
      Phoenix.PubSub.subscribe(@pubsub, Topic.build(@account_id, :typing))
      Phoenix.PubSub.subscribe(@pubsub, Topic.build(@account_id, :connected))
    end
    
    {:ok, assign(socket, messages: [], connected: false)}
  end
  
  def handle_info({:zca_event, _topic, {:message, _account_id, message}}, socket) do
    {:noreply, update(socket, :messages, &(&1 ++ [message]))}
  end
  
  def handle_info({:zca_event, _topic, {:connected, _account_id, _}}, socket) do
    {:noreply, assign(socket, :connected, true)}
  end
  
  def handle_info({:zca_event, _topic, _event}, socket) do
    {:noreply, socket}
  end
end
```

### Runtime Account Management

```elixir
# Get the adapter pid (or use a named process)
adapter = ZcaEx.Adapters.PhoenixPubSub.via("my_adapter")

# Add account at runtime
ZcaEx.Adapters.PhoenixPubSub.add_account(adapter, "new_account")

# Remove account
ZcaEx.Adapters.PhoenixPubSub.remove_account(adapter, "old_account")

# List subscribed accounts
ZcaEx.Adapters.PhoenixPubSub.list_accounts(adapter)
```

## Event System

### Event Types

| Event | Description |
|-------|-------------|
| `:connected` | WebSocket connection established |
| `:disconnected` | WebSocket connection lost |
| `:closed` | WebSocket connection closed |
| `:error` | Error occurred |
| `:message` | New message received |
| `:old_messages` | Historical messages loaded |
| `:reaction` | Message reaction added/removed |
| `:old_reactions` | Historical reactions loaded |
| `:typing` | User typing indicator |
| `:seen` | Message seen receipt |
| `:delivered` | Message delivery confirmation |
| `:friend_event` | Friend list change |
| `:group_event` | Group membership change |
| `:upload_attachment` | Attachment upload progress |
| `:undo` | Message recalled/deleted |
| `:cipher_key` | Encryption key update |

### Topic Format

Topics follow the convention: `zca:<account_id>:<event_type>` or `zca:<account_id>:<event_type>:<sub_type>`

```elixir
# Build topics
ZcaEx.Events.topic("acc123", :message)          # => "zca:acc123:message"
ZcaEx.Events.topic("acc123", :message, :group)  # => "zca:acc123:message:group"

# Parse topics
ZcaEx.Events.Topic.parse("zca:acc123:message")
# => {:ok, %{account_id: "acc123", event_type: :message, sub_type: nil}}
```

### Direct Subscription (without Phoenix)

```elixir
# Subscribe to events
ZcaEx.Events.subscribe("zca:my_account:message")

# Unsubscribe
ZcaEx.Events.unsubscribe("zca:my_account:message")

# Broadcast (used internally)
ZcaEx.Events.broadcast("zca:my_account:message", %{content: "Hello"})
```

## API Reference

### Main Module

| Function | Description |
|----------|-------------|
| `ZcaEx.add_account/2` | Add and start a new account |
| `ZcaEx.remove_account/1` | Stop and remove an account |
| `ZcaEx.login/1` | Authenticate an account |
| `ZcaEx.get_session/1` | Get session for an account |
| `ZcaEx.list_accounts/0` | List all registered account IDs |

### API Endpoints

Located in `ZcaEx.Api.Endpoints.*`:

| Module | Description |
|--------|-------------|
| `SendMessage` | Send text/media messages |
| `GetUserInfo` | Fetch user profile information |
| `GetGroupInfo` | Fetch group details |
| `GetAllFriends` | List all friends |
| `AddReaction` | React to messages |
| `SendTypingEvent` | Send typing indicator |
| `SendSeenEvent` | Mark messages as seen |

### Core Modules

| Module | Description |
|--------|-------------|
| `ZcaEx.Account.Manager` | Per-account GenServer managing state |
| `ZcaEx.Account.Credentials` | Account credential struct |
| `ZcaEx.Account.Session` | Active session data |
| `ZcaEx.Events` | Process group pub/sub system |
| `ZcaEx.Events.Topic` | Topic building helpers |
| `ZcaEx.Adapters.PhoenixPubSub` | Phoenix.PubSub bridge |
| `ZcaEx.WS.Connection` | WebSocket connection handler |
| `ZcaEx.Crypto` | Encryption utilities |

## Configuration

ZcaEx uses runtime configuration via options passed to `add_account/2`:

```elixir
ZcaEx.add_account("account_id", [
  imei: "device_imei",           # Required: Device IMEI
  cookies: "cookie_string",      # Required: Authentication cookies
  user_agent: "Mozilla/5.0...",  # Required: User agent string
  api_type: 30,                  # Optional: API type (default: 30)
  api_version: 637,              # Optional: API version (default: 637)
  language: "vi"                 # Optional: Language code (default: "vi")
])
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.
