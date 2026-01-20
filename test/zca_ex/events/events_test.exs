defmodule ZcaEx.EventsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Events
  alias ZcaEx.Events.Topic
  alias ZcaEx.Events.Dispatcher

  describe "topic/3" do
    test "builds topic without sub_type" do
      assert Events.topic("acc123", :message) == "zca:acc123:message"
    end

    test "builds topic with sub_type" do
      assert Events.topic("acc123", :message, :group) == "zca:acc123:message:group"
    end

    test "builds topic with nil sub_type" do
      assert Events.topic("acc123", :message, nil) == "zca:acc123:message"
    end
  end

  describe "Topic.build/3" do
    test "builds topic for all event types" do
      account_id = "test_account"

      for event_type <- Topic.event_types() do
        topic = Topic.build(account_id, event_type)
        assert topic == "zca:#{account_id}:#{event_type}"
      end
    end

    test "builds topic with sub_type" do
      assert Topic.build("acc", :message, :group) == "zca:acc:message:group"
      assert Topic.build("acc", :reaction, :private) == "zca:acc:reaction:private"
    end
  end

  describe "Topic.topics_for_account/1" do
    test "includes subtype topics for user/group events" do
      topics = Topic.topics_for_account("acc1")

      assert "zca:acc1:message:user" in topics
      assert "zca:acc1:message:group" in topics
      assert "zca:acc1:reaction:user" in topics
      assert "zca:acc1:reaction:group" in topics
      assert "zca:acc1:typing:user" in topics
      assert "zca:acc1:typing:group" in topics
      assert "zca:acc1:seen:user" in topics
      assert "zca:acc1:seen:group" in topics
      assert "zca:acc1:delivered:user" in topics
      assert "zca:acc1:delivered:group" in topics
      assert "zca:acc1:old_messages:user" in topics
      assert "zca:acc1:old_messages:group" in topics
      assert "zca:acc1:old_reactions:user" in topics
      assert "zca:acc1:old_reactions:group" in topics
      assert "zca:acc1:undo:user" in topics
      assert "zca:acc1:undo:group" in topics
      assert "zca:acc1:connected" in topics
      assert "zca:acc1:ready" in topics
    end
  end

  describe "Topic.parse/1" do
    test "parses topic without sub_type" do
      assert {:ok, %{account_id: "acc123", event_type: :message, sub_type: nil}} =
               Topic.parse("zca:acc123:message")
    end

    test "parses topic with sub_type" do
      assert {:ok, %{account_id: "acc123", event_type: :message, sub_type: :group}} =
               Topic.parse("zca:acc123:message:group")
    end

    test "returns error for invalid topic" do
      assert {:error, :invalid_topic} = Topic.parse("invalid")
      assert {:error, :invalid_topic} = Topic.parse("zca:")
      assert {:error, :invalid_topic} = Topic.parse("other:acc:message")
    end

    test "returns error for non-existent atoms" do
      assert {:error, :invalid_topic} = Topic.parse("zca:acc:nonexistent_atom_xyz123")
    end
  end

  describe "subscribe/1 and unsubscribe/1" do
    test "subscribes and unsubscribes current process" do
      topic = Events.topic("test_acc", :message)

      assert :ok = Events.subscribe(topic)

      members = :pg.get_members(Events.pg_scope(), topic)
      assert self() in members

      assert :ok = Events.unsubscribe(topic)

      members = :pg.get_members(Events.pg_scope(), topic)
      refute self() in members
    end

    test "can subscribe to multiple topics" do
      topic1 = Events.topic("test_acc", :message)
      topic2 = Events.topic("test_acc", :reaction)

      Events.subscribe(topic1)
      Events.subscribe(topic2)

      assert self() in :pg.get_members(Events.pg_scope(), topic1)
      assert self() in :pg.get_members(Events.pg_scope(), topic2)

      Events.unsubscribe(topic1)
      Events.unsubscribe(topic2)
    end
  end

  describe "broadcast/2" do
    test "delivers event to subscribed process" do
      topic = Events.topic("test_acc", :message)
      Events.subscribe(topic)

      payload = %{from: "user1", text: "hello"}
      Events.broadcast(topic, payload)

      assert_receive {:zca_event, ^topic, ^payload}

      Events.unsubscribe(topic)
    end

    test "delivers event to multiple subscribers" do
      topic = Events.topic("test_acc", :message)
      parent = self()

      _pids =
        for i <- 1..3 do
          spawn(fn ->
            Events.subscribe(topic)
            send(parent, {:subscribed, i})

            receive do
              {:zca_event, ^topic, payload} ->
                send(parent, {:received, i, payload})
            after
              1000 -> :timeout
            end
          end)
        end

      for i <- 1..3 do
        assert_receive {:subscribed, ^i}
      end

      payload = %{test: "data"}
      Events.broadcast(topic, payload)

      for i <- 1..3 do
        assert_receive {:received, ^i, ^payload}
      end
    end

    test "does not deliver to unsubscribed process" do
      topic = Events.topic("test_acc", :message)
      Events.subscribe(topic)
      Events.unsubscribe(topic)

      Events.broadcast(topic, %{data: "test"})

      refute_receive {:zca_event, _, _}
    end

    test "returns :ok even with no subscribers" do
      topic = Events.topic("nonexistent", :message)
      assert :ok = Events.broadcast(topic, %{data: "test"})
    end
  end

  describe "Dispatcher.dispatch/3" do
    test "dispatches event to topic subscribers" do
      account_id = "dispatch_test"
      topic = Events.topic(account_id, :message)
      Events.subscribe(topic)

      payload = %{content: "hello"}
      Dispatcher.dispatch(account_id, :message, payload)

      assert_receive {:zca_event, ^topic, ^payload}

      Events.unsubscribe(topic)
    end
  end

  describe "Dispatcher.dispatch/4" do
    test "dispatches event with sub_type" do
      account_id = "dispatch_test"
      topic = Events.topic(account_id, :message, :group)
      Events.subscribe(topic)

      payload = %{group_id: "g1", content: "hello"}
      Dispatcher.dispatch(account_id, :message, :group, payload)

      assert_receive {:zca_event, ^topic, ^payload}

      Events.unsubscribe(topic)
    end
  end

  describe "Dispatcher.dispatch_lifecycle/3" do
    test "dispatches lifecycle events" do
      account_id = "lifecycle_test"

      for event <- [:connected, :disconnected, :closed, :error] do
        topic = Events.topic(account_id, event)
        Events.subscribe(topic)

        payload = %{at: DateTime.utc_now()}
        Dispatcher.dispatch_lifecycle(account_id, event, payload)

        assert_receive {:zca_event, ^topic, ^payload}

        Events.unsubscribe(topic)
      end
    end
  end
end
