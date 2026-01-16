defmodule ZcaEx.Adapters.PhoenixPubSubTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Adapters.PhoenixPubSub
  alias ZcaEx.Events

  @moduletag :phoenix_pubsub

  # ZcaEx.Events is already started by the application

  describe "start_link/1" do
    test "starts with required pubsub option" do
      assert {:ok, pid} = PhoenixPubSub.start_link(pubsub: Phoenix.PubSub)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts with accounts option" do
      assert {:ok, pid} =
               PhoenixPubSub.start_link(
                 pubsub: Phoenix.PubSub,
                 accounts: ["acc1", "acc2"]
               )

      assert ["acc1", "acc2"] = PhoenixPubSub.list_accounts(pid) |> Enum.sort()
      GenServer.stop(pid)
    end

    test "starts with name option" do
      assert {:ok, pid} =
               PhoenixPubSub.start_link(
                 pubsub: Phoenix.PubSub,
                 name: :test_adapter
               )

      assert Process.whereis(:test_adapter) == pid
      GenServer.stop(pid)
    end

    test "starts with via tuple name" do
      via = PhoenixPubSub.via("test_adapter")

      assert {:ok, pid} =
               PhoenixPubSub.start_link(
                 pubsub: Phoenix.PubSub,
                 name: via
               )

      assert GenServer.whereis(via) == pid
      GenServer.stop(pid)
    end

    test "fails when pubsub option is missing" do
      Process.flag(:trap_exit, true)
      assert {:error, _} = PhoenixPubSub.start_link([])
    end
  end

  describe "via/1" do
    test "returns a via tuple" do
      assert {:via, Registry, {ZcaEx.Registry, {:phoenix_pubsub, "my_name"}}} =
               PhoenixPubSub.via("my_name")
    end
  end

  describe "add_account/2 and remove_account/2" do
    setup do
      {:ok, pid} = PhoenixPubSub.start_link(pubsub: Phoenix.PubSub)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, adapter: pid}
    end

    test "add_account subscribes to all event types", %{adapter: adapter} do
      assert :ok = PhoenixPubSub.add_account(adapter, "acc123")
      assert ["acc123"] = PhoenixPubSub.list_accounts(adapter)
    end

    test "add_account is idempotent", %{adapter: adapter} do
      assert :ok = PhoenixPubSub.add_account(adapter, "acc123")
      assert :ok = PhoenixPubSub.add_account(adapter, "acc123")
      assert ["acc123"] = PhoenixPubSub.list_accounts(adapter)
    end

    test "remove_account unsubscribes from all event types", %{adapter: adapter} do
      PhoenixPubSub.add_account(adapter, "acc123")
      assert :ok = PhoenixPubSub.remove_account(adapter, "acc123")
      assert [] = PhoenixPubSub.list_accounts(adapter)
    end

    test "remove_account is idempotent", %{adapter: adapter} do
      assert :ok = PhoenixPubSub.remove_account(adapter, "nonexistent")
      assert [] = PhoenixPubSub.list_accounts(adapter)
    end
  end

  describe "event bridging" do
    setup do
      # Start a real Phoenix.PubSub for testing with unique name
      pubsub_name = :"test_pubsub_#{System.unique_integer([:positive])}"

      {:ok, pubsub_sup} =
        Phoenix.PubSub.Supervisor.start_link(name: pubsub_name, adapter: Phoenix.PubSub.PG2)

      {:ok, adapter} =
        PhoenixPubSub.start_link(
          pubsub: pubsub_name,
          accounts: ["acc1"]
        )

      on_exit(fn ->
        try do
          if Process.alive?(adapter), do: GenServer.stop(adapter, :normal, 100)
        catch
          :exit, _ -> :ok
        end

        try do
          if Process.alive?(pubsub_sup), do: Supervisor.stop(pubsub_sup, :normal, 100)
        catch
          :exit, _ -> :ok
        end
      end)

      {:ok, adapter: adapter, pubsub: pubsub_name}
    end

    test "broadcasts :pg events to Phoenix.PubSub", %{pubsub: pubsub} do
      topic = "zca:acc1:message"

      # Subscribe to Phoenix.PubSub
      Phoenix.PubSub.subscribe(pubsub, topic)

      # Wait a bit for adapter to fully subscribe
      Process.sleep(10)

      # Broadcast via :pg
      Events.broadcast(topic, %{text: "hello"})

      # Should receive the event via Phoenix.PubSub
      assert_receive {:zca_event, ^topic, %{text: "hello"}}, 1000
    end

    test "bridges events for multiple accounts", %{adapter: adapter, pubsub: pubsub} do
      PhoenixPubSub.add_account(adapter, "acc2")

      topic1 = "zca:acc1:message"
      topic2 = "zca:acc2:message"

      Phoenix.PubSub.subscribe(pubsub, topic1)
      Phoenix.PubSub.subscribe(pubsub, topic2)

      Process.sleep(10)

      Events.broadcast(topic1, %{from: "acc1"})
      Events.broadcast(topic2, %{from: "acc2"})

      assert_receive {:zca_event, ^topic1, %{from: "acc1"}}, 1000
      assert_receive {:zca_event, ^topic2, %{from: "acc2"}}, 1000
    end

    test "does not bridge events for removed accounts", %{adapter: adapter, pubsub: pubsub} do
      topic = "zca:acc1:message"

      Phoenix.PubSub.subscribe(pubsub, topic)
      Process.sleep(10)

      # Remove the account
      PhoenixPubSub.remove_account(adapter, "acc1")
      Process.sleep(10)

      # Broadcast via :pg
      Events.broadcast(topic, %{text: "should not receive"})

      # Should NOT receive the event
      refute_receive {:zca_event, ^topic, _}, 100
    end
  end

  describe "topic subscription" do
    setup do
      pubsub_name = :"topic_test_pubsub_#{System.unique_integer([:positive])}"

      {:ok, pubsub_sup} =
        Phoenix.PubSub.Supervisor.start_link(name: pubsub_name, adapter: Phoenix.PubSub.PG2)

      {:ok, adapter} =
        PhoenixPubSub.start_link(
          pubsub: pubsub_name,
          accounts: ["acc1"]
        )

      on_exit(fn ->
        try do
          if Process.alive?(adapter), do: GenServer.stop(adapter, :normal, 100)
        catch
          :exit, _ -> :ok
        end

        try do
          if Process.alive?(pubsub_sup), do: Supervisor.stop(pubsub_sup, :normal, 100)
        catch
          :exit, _ -> :ok
        end
      end)

      {:ok, adapter: adapter, pubsub: pubsub_name}
    end

    test "subscribes to all event types for an account", %{pubsub: pubsub} do
      # Test a few different event types
      event_types = [:message, :reaction, :typing, :connected]

      for event_type <- event_types do
        topic = "zca:acc1:#{event_type}"
        Phoenix.PubSub.subscribe(pubsub, topic)
      end

      Process.sleep(10)

      for event_type <- event_types do
        topic = "zca:acc1:#{event_type}"
        Events.broadcast(topic, %{type: event_type})
        assert_receive {:zca_event, ^topic, %{type: ^event_type}}, 1000
      end
    end
  end
end
