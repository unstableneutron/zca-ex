# ZcaEx Examples

Example code showing how to integrate ZcaEx with common Phoenix patterns.

**Important**: These are examples only, not dependencies. Copy and adapt them for your application.

## Available Examples

### ChatLive (`chat_live.ex`)

A Phoenix LiveView example demonstrating real-time chat with ZcaEx.

## Quick Start

### 1. Configure Your Supervision Tree

```elixir
# application.ex
def start(_type, _args) do
  children = [
    # Start PubSub
    {Phoenix.PubSub, name: MyApp.PubSub},
    
    # Start ZcaEx PubSub adapter to bridge events
    {ZcaEx.Adapters.PhoenixPubSub,
      pubsub: MyApp.PubSub,
      accounts: ["your_account_id"]}
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 2. Copy the Example

Copy `chat_live.ex` to your Phoenix app:

```bash
cp deps/zca_ex/lib/zca_ex/examples/chat_live.ex \
   lib/my_app_web/live/chat_live.ex
```

### 3. Update Module Configuration

Edit the copied file:

```elixir
defmodule MyAppWeb.ChatLive do
  # ...
  
  @pubsub MyApp.PubSub
  @account_id "your_actual_account_id"
  
  # ...
end
```

### 4. Add Route

```elixir
# router.ex
scope "/", MyAppWeb do
  pipe_through :browser
  
  live "/chat", ChatLive
  live "/chat/:thread_id/:type", ChatLive
end
```

## Event Reference

ZcaEx events are delivered as `{:zca_event, topic, event_tuple}` messages.

### Message Events

```elixir
# Incoming message
{:zca_event, "zca:account_id:message", {:message, account_id, %{
  "msgId" => 123456,
  "content" => "Hello!",
  "uidFrom" => "sender_id",
  "ts" => 1699999999999,
  "msgType" => "chat.text"
}}}
```

### Typing Events

```elixir
# User started/stopped typing
{:zca_event, "zca:account_id:typing", {:typing, account_id, %{
  "uid" => "user_id",
  "isTyping" => true,
  "threadId" => "thread_id",
  "threadType" => "user"
}}}
```

### Connection Events

```elixir
# Connected
{:zca_event, "zca:account_id:connected", {:connected, account_id, %{}}}

# Disconnected
{:zca_event, "zca:account_id:disconnected", {:disconnected, account_id, reason}}
```

### Other Events

- `:seen` - Message read receipts
- `:delivered` - Message delivery confirmations  
- `:reaction` - Message reactions (emoji)
- `:friend_event` - Friend list changes
- `:group_event` - Group membership changes

## Topic Naming

Topics follow the pattern: `zca:<account_id>:<event_type>`

Use `ZcaEx.Events.Topic.build/2` to construct topics:

```elixir
alias ZcaEx.Events.Topic

Topic.build("my_account", :message)    # => "zca:my_account:message"
Topic.build("my_account", :typing)     # => "zca:my_account:typing"
Topic.build("my_account", :connected)  # => "zca:my_account:connected"
```

## Subscribing to Events

Subscribe in your LiveView's `mount/3` callback:

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, Topic.build(@account_id, :message))
    Phoenix.PubSub.subscribe(MyApp.PubSub, Topic.build(@account_id, :typing))
  end
  
  {:ok, socket}
end
```

## Sending Messages

Use `ZcaEx.Api.Endpoints.SendMessage`:

```elixir
alias ZcaEx.Api.Endpoints.SendMessage
alias ZcaEx.Account.Manager

session = Manager.get_session(account_id)

# Simple text message
SendMessage.send("Hello!", "user_id", :user, session, credentials)

# Message to a group
SendMessage.send("Hello group!", "group_id", :group, session, credentials)

# Message with mentions (groups only)
SendMessage.send(
  %{msg: "Hi @everyone", mentions: [%{uid: "-1", pos: 3, len: 9}]},
  "group_id",
  :group,
  session,
  credentials
)
```

## Multi-Account Support

For multiple accounts, subscribe to events from each:

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    for account_id <- ["account1", "account2"] do
      Phoenix.PubSub.subscribe(@pubsub, Topic.build(account_id, :message))
    end
  end
  
  {:ok, socket}
end

def handle_info({:zca_event, topic, {:message, account_id, msg}}, socket) do
  # account_id tells you which account received the message
  {:noreply, socket}
end
```
