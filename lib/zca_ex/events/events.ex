defmodule ZcaEx.Events do
  @moduledoc """
  Process group based pub/sub for ZcaEx events.

  Uses :pg (process groups) for lightweight pub/sub without external dependencies.
  """

  alias ZcaEx.Events.Topic

  @pg_scope __MODULE__

  @doc """
  Returns a child spec for starting the :pg scope.

  Call from Application supervisor:

      children = [
        {ZcaEx.Events, []}
      ]

  """
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  @doc """
  Starts the :pg scope for ZcaEx events.
  """
  @spec start_link() :: {:ok, pid()} | {:error, term()}
  def start_link do
    :pg.start_link(@pg_scope)
  end

  @doc """
  Subscribe the current process to a topic.

  ## Examples

      ZcaEx.Events.subscribe("zca:acc123:message")

  """
  @spec subscribe(String.t()) :: :ok
  def subscribe(topic) when is_binary(topic) do
    :pg.join(@pg_scope, topic, self())
  end

  @doc """
  Unsubscribe the current process from a topic.

  ## Examples

      ZcaEx.Events.unsubscribe("zca:acc123:message")

  """
  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(topic) when is_binary(topic) do
    :pg.leave(@pg_scope, topic, self())
  end

  @doc """
  Broadcast an event to all subscribers of a topic.

  ## Examples

      ZcaEx.Events.broadcast("zca:acc123:message", %{from: "user1", text: "hello"})

  """
  @spec broadcast(String.t(), term()) :: :ok
  def broadcast(topic, event) when is_binary(topic) do
    members = :pg.get_members(@pg_scope, topic)

    Enum.each(members, fn pid ->
      send(pid, {:zca_event, topic, event})
    end)

    :ok
  end

  @doc """
  Build a topic string for the given account, event type, and optional sub-type.

  Delegates to `ZcaEx.Events.Topic.build/3`.

  ## Examples

      iex> ZcaEx.Events.topic("acc123", :message)
      "zca:acc123:message"

      iex> ZcaEx.Events.topic("acc123", :message, :group)
      "zca:acc123:message:group"

  """
  @spec topic(account_id :: String.t(), event_type :: atom(), sub_type :: atom() | nil) ::
          String.t()
  def topic(account_id, event_type, sub_type \\ nil) do
    Topic.build(account_id, event_type, sub_type)
  end

  @doc """
  Returns the :pg scope used by ZcaEx.Events.
  """
  @spec pg_scope() :: atom()
  def pg_scope, do: @pg_scope
end
