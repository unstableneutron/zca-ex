# This module only compiles when Phoenix.LiveView is available
if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule ZcaEx.Examples.ChatLive do
    @moduledoc """
    Example LiveView showing ZcaEx integration.

    This is NOT a dependency - copy and adapt for your application.

    ## Setup

    1. Add Phoenix.PubSub and ZcaEx.Adapters.PhoenixPubSub to your supervision tree:

        children = [
          {Phoenix.PubSub, name: MyApp.PubSub},
          {ZcaEx.Adapters.PhoenixPubSub,
            pubsub: MyApp.PubSub,
            accounts: ["your_account_id"]}
        ]

    2. Copy this module to your Phoenix app (e.g., lib/my_app_web/live/chat_live.ex)

    3. Update the module name and configuration to match your app

    4. Add route in your router:

        live "/chat", ChatLive

    ## Events Handled

    - `{:zca_event, topic, {:message, account_id, message}}` - Incoming messages
    - `{:zca_event, topic, {:typing, account_id, typing_info}}` - Typing indicators
    - `{:zca_event, topic, {:connected, account_id, info}}` - Connection established
    - `{:zca_event, topic, {:disconnected, account_id, reason}}` - Connection lost
    """

    use Phoenix.LiveView

  alias ZcaEx.Events.Topic
  alias ZcaEx.Api.Endpoints.SendMessage
  alias ZcaEx.Account.Manager

  # ============================================================================
  # Configuration - Update these for your app
  # ============================================================================

  # Your Phoenix.PubSub module name
  @pubsub MyApp.PubSub

  # The Zalo account ID to use
  @account_id "your_account_id"

  # ============================================================================
  # LiveView Callbacks
  # ============================================================================

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to ZcaEx events when the LiveView mounts
    # Only subscribe on connected (browser) mount, not during static render
    if connected?(socket) do
      subscribe_to_zca_events()
    end

    {:ok,
     assign(socket,
       messages: [],
       typing_users: MapSet.new(),
       connected: false,
       current_thread: nil,
       message_input: ""
     )}
  end

  @impl true
  def handle_params(%{"thread_id" => thread_id, "type" => type}, _uri, socket) do
    thread_type = String.to_existing_atom(type)

    {:noreply,
     assign(socket,
       current_thread: %{id: thread_id, type: thread_type}
     )}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # ZcaEx Event Handlers
  # ============================================================================

  @impl true
  def handle_info({:zca_event, _topic, {:message, _account_id, message}}, socket) do
    # Handle incoming message
    # Message structure depends on the message type (text, image, etc.)
    new_message = %{
      id: message["msgId"],
      content: message["content"],
      from: message["uidFrom"],
      timestamp: message["ts"],
      type: message["msgType"]
    }

    {:noreply, update(socket, :messages, fn msgs -> msgs ++ [new_message] end)}
  end

  def handle_info({:zca_event, _topic, {:typing, _account_id, typing_info}}, socket) do
    # Handle typing indicator
    # typing_info contains: uid, isTyping, threadId, threadType
    uid = typing_info["uid"]
    is_typing = typing_info["isTyping"]

    new_typing =
      if is_typing do
        MapSet.put(socket.assigns.typing_users, uid)
      else
        MapSet.delete(socket.assigns.typing_users, uid)
      end

    {:noreply, assign(socket, :typing_users, new_typing)}
  end

  def handle_info({:zca_event, _topic, {:connected, _account_id, _info}}, socket) do
    # Handle connection established
    {:noreply, assign(socket, :connected, true)}
  end

  def handle_info({:zca_event, _topic, {:disconnected, _account_id, _reason}}, socket) do
    # Handle connection lost
    {:noreply, assign(socket, :connected, false)}
  end

  def handle_info({:zca_event, _topic, {:seen, _account_id, seen_info}}, socket) do
    # Handle seen receipts - mark messages as read
    # seen_info contains: uid, msgId, threadId
    {:noreply, socket}
  end

  def handle_info({:zca_event, _topic, {:delivered, _account_id, delivery_info}}, socket) do
    # Handle delivery receipts
    # delivery_info contains: uid, msgId, threadId
    {:noreply, socket}
  end

  def handle_info({:zca_event, _topic, {:reaction, _account_id, reaction_info}}, socket) do
    # Handle message reactions
    # reaction_info contains: msgId, reactions, uid
    {:noreply, socket}
  end

  def handle_info({:zca_event, _topic, _event}, socket) do
    # Catch-all for other events
    {:noreply, socket}
  end

  # ============================================================================
  # User Action Handlers
  # ============================================================================

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    case socket.assigns.current_thread do
      nil ->
        {:noreply, put_flash(socket, :error, "No thread selected")}

      %{id: thread_id, type: thread_type} ->
        case send_message(message, thread_id, thread_type) do
          {:ok, _result} ->
            {:noreply, assign(socket, :message_input, "")}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, "Failed to send: #{inspect(error)}")}
        end
    end
  end

  def handle_event("update_input", %{"message" => value}, socket) do
    {:noreply, assign(socket, :message_input, value)}
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chat-container">
      <!-- Connection Status -->
      <div class={"connection-status #{if @connected, do: "connected", else: "disconnected"}"}>
        <%= if @connected, do: "Connected", else: "Disconnected" %>
      </div>

      <!-- Messages List -->
      <div class="messages-list">
        <%= for message <- @messages do %>
          <div class="message" id={"message-#{message.id}"}>
            <span class="from"><%= message.from %></span>
            <span class="content"><%= message.content %></span>
            <span class="timestamp"><%= format_timestamp(message.timestamp) %></span>
          </div>
        <% end %>
      </div>

      <!-- Typing Indicator -->
      <%= if MapSet.size(@typing_users) > 0 do %>
        <div class="typing-indicator">
          <%= typing_text(@typing_users) %> typing...
        </div>
      <% end %>

      <!-- Message Input -->
      <form phx-submit="send_message" class="message-form">
        <input
          type="text"
          name="message"
          value={@message_input}
          phx-change="update_input"
          placeholder="Type a message..."
          autocomplete="off"
        />
        <button type="submit" disabled={@message_input == ""}>Send</button>
      </form>
    </div>
    """
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp subscribe_to_zca_events do
    # Subscribe to message events
    Phoenix.PubSub.subscribe(@pubsub, Topic.build(@account_id, :message))

    # Subscribe to typing events
    Phoenix.PubSub.subscribe(@pubsub, Topic.build(@account_id, :typing))

    # Subscribe to connection lifecycle events
    Phoenix.PubSub.subscribe(@pubsub, Topic.build(@account_id, :connected))
    Phoenix.PubSub.subscribe(@pubsub, Topic.build(@account_id, :disconnected))

    # Subscribe to additional events as needed
    Phoenix.PubSub.subscribe(@pubsub, Topic.build(@account_id, :seen))
    Phoenix.PubSub.subscribe(@pubsub, Topic.build(@account_id, :delivered))
    Phoenix.PubSub.subscribe(@pubsub, Topic.build(@account_id, :reaction))
  end

  defp send_message(content, thread_id, thread_type) do
    # Get session and credentials for the account
    # In a real app, you'd fetch these from your account management system
    session = Manager.get_session(@account_id)
    credentials = get_credentials()

    if session do
      SendMessage.send(content, thread_id, thread_type, session, credentials)
    else
      {:error, :not_logged_in}
    end
  end

  defp get_credentials do
    # In a real app, load credentials from your configuration
    # This is just a placeholder structure
    %ZcaEx.Account.Credentials{
      imei: "your_imei",
      cookies: [],
      user_agent: "Mozilla/5.0",
      api_type: 30,
      api_version: 637,
      language: "vi"
    }
  end

  defp format_timestamp(nil), do: ""

  defp format_timestamp(ts) when is_integer(ts) do
    ts
    |> DateTime.from_unix!(:millisecond)
    |> Calendar.strftime("%H:%M")
  end

  defp typing_text(typing_users) do
    users = MapSet.to_list(typing_users)

    case length(users) do
      1 -> "Someone is"
      n -> "#{n} people are"
    end
  end
end
end
