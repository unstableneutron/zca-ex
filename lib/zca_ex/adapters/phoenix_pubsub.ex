defmodule ZcaEx.Adapters.PhoenixPubSub do
  @moduledoc """
  Bridge ZcaEx events to Phoenix.PubSub.

  This adapter subscribes to ZcaEx's :pg-based events and broadcasts them
  to Phoenix.PubSub, enabling Phoenix LiveView integration.

  ## Usage

      # In your application.ex
      children = [
        {ZcaEx.Adapters.PhoenixPubSub,
          pubsub: MyApp.PubSub,
          accounts: ["account1", "account2"]}
      ]

      # In your LiveView
      def mount(_params, _session, socket) do
        Phoenix.PubSub.subscribe(MyApp.PubSub, "zca:account1:message:user")
        {:ok, socket}
      end

      def handle_info({:zca_event, _topic, event}, socket) do
        # Handle event
        {:noreply, socket}
      end

  ## Options

    * `:pubsub` - Required. The Phoenix.PubSub module to broadcast to.
    * `:accounts` - Optional. List of account IDs to subscribe to on start.
    * `:name` - Optional. Name for the GenServer process.

  ## Runtime Management

      # Add an account at runtime
      ZcaEx.Adapters.PhoenixPubSub.add_account(adapter_pid, "account3")

      # Remove an account
      ZcaEx.Adapters.PhoenixPubSub.remove_account(adapter_pid, "account3")

  """

  use GenServer

  alias ZcaEx.Events
  alias ZcaEx.Events.Topic

  require Logger

  @type account_id :: String.t()
  @type opts :: [
          pubsub: module(),
          accounts: [account_id()],
          name: GenServer.name()
        ]

  defstruct [:pubsub, accounts: MapSet.new()]

  @doc """
  Starts the Phoenix.PubSub adapter.

  ## Options

    * `:pubsub` - Required. The Phoenix.PubSub module.
    * `:accounts` - Optional. List of account IDs to subscribe to.
    * `:name` - Optional. GenServer name or `{:via, Registry, ...}` tuple.

  """
  @spec start_link(opts()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    case name do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc """
  Returns a via tuple for Registry-based naming.

  ## Example

      {:via, Registry, {ZcaEx.Registry, {:phoenix_pubsub, "my_adapter"}}}
      = ZcaEx.Adapters.PhoenixPubSub.via("my_adapter")

  """
  @spec via(String.t()) :: {:via, Registry, {ZcaEx.Registry, {:phoenix_pubsub, String.t()}}}
  def via(name) when is_binary(name) do
    {:via, Registry, {ZcaEx.Registry, {:phoenix_pubsub, name}}}
  end

  @doc """
  Adds an account to the adapter at runtime.

  Subscribes to all event types for the given account.
  """
  @spec add_account(GenServer.server(), account_id()) :: :ok
  def add_account(server, account_id) when is_binary(account_id) do
    GenServer.call(server, {:add_account, account_id})
  end

  @doc """
  Removes an account from the adapter at runtime.

  Unsubscribes from all event types for the given account.
  """
  @spec remove_account(GenServer.server(), account_id()) :: :ok
  def remove_account(server, account_id) when is_binary(account_id) do
    GenServer.call(server, {:remove_account, account_id})
  end

  @doc """
  Returns the list of accounts this adapter is subscribed to.
  """
  @spec list_accounts(GenServer.server()) :: [account_id()]
  def list_accounts(server) do
    GenServer.call(server, :list_accounts)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    case check_phoenix_pubsub() do
      :ok ->
        pubsub = Keyword.fetch!(opts, :pubsub)
        accounts = Keyword.get(opts, :accounts, [])

        state = %__MODULE__{pubsub: pubsub}

        state =
          Enum.reduce(accounts, state, fn account_id, acc ->
            subscribe_account(account_id)
            %{acc | accounts: MapSet.put(acc.accounts, account_id)}
          end)

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:add_account, account_id}, _from, state) do
    if MapSet.member?(state.accounts, account_id) do
      {:reply, :ok, state}
    else
      subscribe_account(account_id)
      new_accounts = MapSet.put(state.accounts, account_id)
      {:reply, :ok, %{state | accounts: new_accounts}}
    end
  end

  def handle_call({:remove_account, account_id}, _from, state) do
    if MapSet.member?(state.accounts, account_id) do
      unsubscribe_account(account_id)
      new_accounts = MapSet.delete(state.accounts, account_id)
      {:reply, :ok, %{state | accounts: new_accounts}}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call(:list_accounts, _from, state) do
    {:reply, MapSet.to_list(state.accounts), state}
  end

  @impl true
  def handle_info({:zca_event, topic, event}, state) do
    Phoenix.PubSub.broadcast(state.pubsub, topic, {:zca_event, topic, event})
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private helpers

  defp check_phoenix_pubsub do
    if Code.ensure_loaded?(Phoenix.PubSub) do
      :ok
    else
      {:error, :phoenix_pubsub_not_available}
    end
  end

  defp subscribe_account(account_id) do
    for topic <- Topic.topics_for_account(account_id) do
      Events.subscribe(topic)
    end

    :ok
  end

  defp unsubscribe_account(account_id) do
    for topic <- Topic.topics_for_account(account_id) do
      Events.unsubscribe(topic)
    end

    :ok
  end
end
