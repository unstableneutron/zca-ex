defmodule ZcaEx.Events.Dispatcher do
  @moduledoc """
  Event dispatching for internal use by WS.Connection.

  Provides a simple interface for broadcasting events from the WebSocket connection
  to all subscribers.
  """

  alias ZcaEx.Events
  alias ZcaEx.Events.Topic

  @doc """
  Dispatch an event to all subscribers for the given account and event type.

  Broadcasts to the topic `zca:\<account_id\>:\<event_type\>`.

  ## Examples

      ZcaEx.Events.Dispatcher.dispatch("acc123", :message, %{from: "user1", text: "hello"})

  """
  @spec dispatch(account_id :: String.t() | atom(), event_type :: atom(), payload :: term()) :: :ok
  def dispatch(account_id, event_type, payload) when is_atom(account_id) do
    dispatch(Atom.to_string(account_id), event_type, payload)
  end

  def dispatch(account_id, event_type, payload)
      when is_binary(account_id) and is_atom(event_type) do
    topic = Topic.build(account_id, event_type)
    Events.broadcast(topic, payload)
  end

  @doc """
  Dispatch an event with a sub-type to all subscribers.

  Broadcasts to the topic `zca:\<account_id\>:\<event_type\>:\<sub_type\>` (substituting actual values).

  ## Examples

      ZcaEx.Events.Dispatcher.dispatch("acc123", :message, :group, %{group_id: "g1", text: "hi"})

  """
  @spec dispatch(
          account_id :: String.t(),
          event_type :: atom(),
          sub_type :: atom(),
          payload :: term()
        ) :: :ok
  def dispatch(account_id, event_type, sub_type, payload)
      when is_binary(account_id) and is_atom(event_type) and is_atom(sub_type) do
    topic = Topic.build(account_id, event_type, sub_type)
    Events.broadcast(topic, payload)
  end

  @doc """
  Dispatch a connection lifecycle event.

  Convenience function for :connected, :disconnected, :closed, :error events.

  ## Examples

      ZcaEx.Events.Dispatcher.dispatch_lifecycle("acc123", :connected, %{at: DateTime.utc_now()})

  """
  @spec dispatch_lifecycle(
          account_id :: String.t(),
          event :: :connected | :disconnected | :closed | :error | :ready,
          payload :: term()
        ) :: :ok
  def dispatch_lifecycle(account_id, event, payload)
      when event in [:connected, :disconnected, :closed, :error, :ready] do
    dispatch(account_id, event, payload)
  end
end
