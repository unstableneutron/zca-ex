# Listen for WebSocket events (friend requests, messages, etc.)
# Usage: mix run scripts/listen_events.exs
#
# This script connects to Zalo WebSocket and logs all incoming events.
# Useful for debugging and capturing new event types.

# Enable debug logging
Logger.configure(level: :debug)

defmodule EventListener do
  use GenServer
  require Logger

  alias ZcaEx.Events
  alias ZcaEx.Events.Topic

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    
    IO.puts("\n=== Event Listener Started ===")
    IO.puts("Subscribing to events for account: #{account_id}")
    IO.puts("Press Ctrl+C to stop.\n")
    
    # Subscribe to all event types using :pg
    for event_type <- Topic.event_types() do
      topic = Events.topic(account_id, event_type)
      IO.puts("  Subscribed to: #{topic}")
      Events.subscribe(topic)
    end
    
    # Also subscribe to sub-types for message and old_messages
    for sub_type <- [:user, :group] do
      for event_type <- [:message, :old_messages, :reaction, :old_reactions] do
        topic = Events.topic(account_id, event_type, sub_type)
        IO.puts("  Subscribed to: #{topic}")
        Events.subscribe(topic)
      end
    end
    
    {:ok, %{account_id: account_id}}
  end

  @impl true
  def handle_info({:zca_event, topic, payload}, state) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    
    IO.puts("\n#{timestamp}")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("Topic: #{topic}")
    IO.puts("Payload:")
    IO.inspect(payload, pretty: true, limit: :infinity)
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    
    # Special handling for friend events
    case Topic.parse(topic) do
      {:ok, %{event_type: :friend_event}} ->
        act = payload[:act] || payload["act"]
        IO.puts("🔔 FRIEND EVENT: act=#{act}")
        
      {:ok, %{event_type: :message}} ->
        from = get_in(payload, [:from_uid]) || get_in(payload, ["fromUid"])
        IO.puts("💬 MESSAGE from #{from}")
        
      {:ok, %{event_type: :cipher_key}} ->
        IO.puts("🔑 CIPHER KEY received - connection ready!")
        
      {:ok, %{event_type: :connected}} ->
        IO.puts("✅ CONNECTED to WebSocket")
        
      {:ok, %{event_type: :disconnected}} ->
        IO.puts("❌ DISCONNECTED from WebSocket")
        
      {:ok, %{event_type: :error}} ->
        IO.puts("⚠️ ERROR: #{inspect(payload)}")
        
      _ ->
        :ok
    end
    
    {:noreply, state}
  end

  def handle_info(msg, state) do
    IO.puts("\n[OTHER] #{inspect(msg)}")
    {:noreply, state}
  end
end

# --- Main ---

alias ZcaEx.Account.{Credentials, Manager}
alias ZcaEx.Account.Supervisor, as: AccountSupervisor
alias ZcaEx.WS.Connection

# Use a consistent account_id throughout
account_id = "listener"

IO.puts("Loading credentials...")
{:ok, json} = File.read("scripts/credentials.json")
{:ok, map} = Jason.decode(json)
{:ok, credentials} = Credentials.from_map(map)

IO.puts("Starting application...")
Application.ensure_all_started(:zca_ex)

IO.puts("Starting account supervisor for account_id: #{account_id}...")
case AccountSupervisor.start_link(account_id: account_id, credentials: credentials) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

IO.puts("Logging in...")
{:ok, session} = Manager.login(account_id)
IO.puts("✓ Logged in as UID: #{session.uid}")

# Debug: show WS endpoints
IO.puts("\nWS Endpoints:")
for ep <- session.ws_endpoints do
  IO.puts("  #{ep}")
end

# Debug: show cookies
cookies = ZcaEx.CookieJar.get_cookie_string(account_id, "https://chat.zalo.me")
IO.puts("\nCookies (first 100 chars): #{String.slice(cookies, 0, 100)}...")

IO.puts("\nStarting event listener (subscribes to :pg topics)...")
# Use account_id (not session.uid) since that's what WS.Connection will use
{:ok, _} = EventListener.start_link(account_id: account_id)

IO.puts("\nStarting WebSocket connection...")
# Start the WS Connection GenServer with same account_id
{:ok, _ws_pid} = Connection.start_link(account_id: account_id)
# Connect with the session
:ok = Connection.connect(account_id, session)

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("READY - Waiting for events...")
IO.puts("Ask your friend to accept the friend request now.")
IO.puts(String.duplicate("=", 50) <> "\n")

# Keep the script running
Process.sleep(:infinity)
