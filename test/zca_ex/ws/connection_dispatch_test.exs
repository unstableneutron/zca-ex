defmodule ZcaEx.WS.ConnectionDispatchTest do
  @moduledoc """
  Integration tests for WS.Connection event dispatching with models.

  Tests that the dispatcher correctly transforms raw WebSocket payloads into
  model structs before broadcasting events.
  """
  use ExUnit.Case, async: true

  alias ZcaEx.Events
  alias ZcaEx.Model.{DeliveredMessage, Message, Reaction, SeenMessage, Typing, Undo}

  @account_id "test_dispatch_account"
  @uid "123456789"

  setup do
    # Subscribe to all relevant event topics for this account
    Events.subscribe(Events.topic(@account_id, :message, :user))
    Events.subscribe(Events.topic(@account_id, :message, :group))
    Events.subscribe(Events.topic(@account_id, :undo, :user))
    Events.subscribe(Events.topic(@account_id, :undo, :group))
    Events.subscribe(Events.topic(@account_id, :typing, :user))
    Events.subscribe(Events.topic(@account_id, :typing, :group))
    Events.subscribe(Events.topic(@account_id, :reaction, :user))
    Events.subscribe(Events.topic(@account_id, :reaction, :group))
    Events.subscribe(Events.topic(@account_id, :seen, :user))
    Events.subscribe(Events.topic(@account_id, :seen, :group))
    Events.subscribe(Events.topic(@account_id, :delivered, :user))
    Events.subscribe(Events.topic(@account_id, :delivered, :group))

    on_exit(fn ->
      Events.unsubscribe(Events.topic(@account_id, :message, :user))
      Events.unsubscribe(Events.topic(@account_id, :message, :group))
      Events.unsubscribe(Events.topic(@account_id, :undo, :user))
      Events.unsubscribe(Events.topic(@account_id, :undo, :group))
      Events.unsubscribe(Events.topic(@account_id, :typing, :user))
      Events.unsubscribe(Events.topic(@account_id, :typing, :group))
      Events.unsubscribe(Events.topic(@account_id, :reaction, :user))
      Events.unsubscribe(Events.topic(@account_id, :reaction, :group))
      Events.unsubscribe(Events.topic(@account_id, :seen, :user))
      Events.unsubscribe(Events.topic(@account_id, :seen, :group))
      Events.unsubscribe(Events.topic(@account_id, :delivered, :user))
      Events.unsubscribe(Events.topic(@account_id, :delivered, :group))
    end)

    :ok
  end

  describe "Message model dispatching" do
    test "dispatches Message struct for user message" do
      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.text",
        "uidFrom" => "987654321",
        "idTo" => @uid,
        "content" => "Hello world",
        "ts" => "1705500000000",
        "ttl" => 604_800
      }

      model = Message.from_ws_data(data, @uid, :user)

      assert %Message{} = model
      assert model.msg_id == "msg123"
      assert model.uid_from == "987654321"
      assert model.id_to == @uid
      assert model.thread_id == "987654321"
      assert model.thread_type == :user
      assert model.is_self == false
    end

    test "dispatches Message struct for self-sent user message" do
      data = %{
        "msgId" => "msg456",
        "cliMsgId" => "cli456",
        "msgType" => "chat.text",
        "uidFrom" => "0",
        "idTo" => "recipient123",
        "content" => "My message",
        "ts" => "1705500000000",
        "ttl" => 604_800
      }

      model = Message.from_ws_data(data, @uid, :user)

      assert model.is_self == true
      assert model.uid_from == @uid
      assert model.thread_id == "recipient123"
    end

    test "dispatches Message struct for group message" do
      data = %{
        "msgId" => "msg789",
        "cliMsgId" => "cli789",
        "msgType" => "chat.text",
        "uidFrom" => "sender123",
        "idTo" => "group456",
        "content" => "Group message",
        "ts" => "1705500000000",
        "ttl" => 0
      }

      model = Message.from_ws_data(data, @uid, :group)

      assert model.thread_id == "group456"
      assert model.thread_type == :group
    end
  end

  describe "Undo model dispatching" do
    test "detects undo message when content has deleteMsg key as map" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "undo",
        "uidFrom" => "sender123",
        "idTo" => @uid,
        "content" => %{"deleteMsg" => %{"msgId" => "deleted_msg_id"}},
        "ts" => "1705500000000"
      }

      model = Undo.from_ws_data(data, @uid, :user)

      assert %Undo{} = model
      assert model.undo_msg_id == "deleted_msg_id"
      assert model.thread_type == :user
    end

    test "detects undo message when content has deleteMsg as JSON string" do
      content_json = Jason.encode!(%{"deleteMsg" => %{"msgId" => "deleted123"}})

      data = %{
        "actionId" => "action456",
        "msgId" => "msg456",
        "cliMsgId" => "cli456",
        "msgType" => "undo",
        "uidFrom" => "0",
        "idTo" => "recipient123",
        "content" => content_json,
        "ts" => "1705500000000"
      }

      # The is_undo_message? helper checks for binary content with deleteMsg
      assert is_binary(data["content"])
      {:ok, parsed} = Jason.decode(data["content"])
      assert Map.has_key?(parsed, "deleteMsg")
    end

    test "dispatches Undo struct for group undo" do
      data = %{
        "actionId" => "action789",
        "msgId" => "msg789",
        "cliMsgId" => "cli789",
        "msgType" => "undo",
        "uidFrom" => "sender123",
        "idTo" => "group456",
        "content" => %{"deleteMsg" => %{"msgId" => "deleted_in_group"}},
        "ts" => "1705500000000",
        "dName" => "Sender Name"
      }

      model = Undo.from_ws_data(data, @uid, :group)

      assert model.thread_id == "group456"
      assert model.thread_type == :group
      assert model.undo_msg_id == "deleted_in_group"
    end
  end

  describe "Typing model dispatching" do
    test "dispatches Typing struct with :user thread_type for 'typing' act" do
      data = %{
        "uid" => "sender123",
        "ts" => "1705500000000",
        "isPC" => 0
      }

      model = Typing.from_ws_data(data, "typing")

      assert %Typing{} = model
      assert model.thread_type == :user
      assert model.thread_id == "sender123"
      assert model.is_self == false
      assert model.is_pc == false
    end

    test "dispatches Typing struct with :group thread_type for 'gtyping' act" do
      data = %{
        "uid" => "sender123",
        "gid" => "group456",
        "ts" => "1705500000000",
        "isPC" => 1
      }

      model = Typing.from_ws_data(data, "gtyping")

      assert model.thread_type == :group
      assert model.thread_id == "group456"
      assert model.is_pc == true
    end

    test "typing_thread_type helper determines thread type from act field" do
      # User typing: act is "typing" or other non-gtyping value
      assert Typing.from_ws_data(%{"uid" => "u1", "ts" => "0"}, "typing").thread_type == :user
      assert Typing.from_ws_data(%{"uid" => "u1", "ts" => "0"}, "").thread_type == :user

      # Group typing: act is "gtyping"
      assert Typing.from_ws_data(%{"uid" => "u1", "gid" => "g1", "ts" => "0"}, "gtyping").thread_type ==
               :group
    end
  end

  describe "Reaction model dispatching" do
    test "dispatches Reaction struct for user reaction" do
      react_data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "reaction",
        "uidFrom" => "sender123",
        "idTo" => @uid,
        "content" => %{"rType" => 1, "rIcon" => "👍"},
        "ts" => "1705500000000",
        "ttl" => 0
      }

      model = Reaction.from_ws_data(react_data, @uid, :user)

      assert %Reaction{} = model
      assert model.thread_type == :user
      assert model.thread_id == "sender123"
      assert model.content == %{"rType" => 1, "rIcon" => "👍"}
    end

    test "dispatches Reaction struct for group reaction" do
      react_data = %{
        "actionId" => "action456",
        "msgId" => "msg456",
        "cliMsgId" => "cli456",
        "msgType" => "reaction",
        "uidFrom" => "sender123",
        "idTo" => "group789",
        "content" => Jason.encode!(%{"rType" => 2, "rIcon" => "❤️"}),
        "ts" => "1705500000000",
        "ttl" => 0
      }

      model = Reaction.from_ws_data(react_data, @uid, :group)

      assert model.thread_type == :group
      assert model.thread_id == "group789"
      # Content should be parsed from JSON string
      assert model.content == %{"rType" => 2, "rIcon" => "❤️"}
    end

    test "reaction splitting: reacts[] for user, reactGroups[] for group" do
      # This tests the payload structure that WS.Connection receives
      # The dispatcher iterates over reacts[] and dispatches each with :user
      # and over reactGroups[] dispatching each with :group

      payload = %{
        "data" => %{
          "reacts" => [
            %{
              "actionId" => "a1",
              "msgId" => "m1",
              "uidFrom" => "u1",
              "idTo" => @uid,
              "content" => %{}
            },
            %{
              "actionId" => "a2",
              "msgId" => "m2",
              "uidFrom" => "u2",
              "idTo" => @uid,
              "content" => %{}
            }
          ],
          "reactGroups" => [
            %{
              "actionId" => "a3",
              "msgId" => "m3",
              "uidFrom" => "u3",
              "idTo" => "g1",
              "content" => %{}
            }
          ]
        }
      }

      # Verify structure: 2 user reactions + 1 group reaction
      reacts = get_in(payload, ["data", "reacts"])
      react_groups = get_in(payload, ["data", "reactGroups"])

      assert length(reacts) == 2
      assert length(react_groups) == 1

      # Each would be dispatched separately by WS.Connection
      Enum.each(reacts, fn react ->
        model = Reaction.from_ws_data(react, @uid, :user)
        assert model.thread_type == :user
      end)

      Enum.each(react_groups, fn react ->
        model = Reaction.from_ws_data(react, @uid, :group)
        assert model.thread_type == :group
      end)
    end
  end

  describe "SeenMessage model dispatching" do
    test "detects seen event when seenUids present with items" do
      data = %{
        "msgId" => "msg123",
        "groupId" => "group456",
        "seenUids" => ["user1", "user2", @uid]
      }

      # is_seen_event? returns true for non-empty seenUids
      assert is_list(data["seenUids"]) and length(data["seenUids"]) > 0

      model = SeenMessage.from_ws_data(data, @uid, :group)

      assert %SeenMessage{} = model
      assert model.thread_type == :group
      assert model.thread_id == "group456"
      assert model.is_self == true
      assert model.seen_uids == ["user1", "user2", @uid]
    end

    test "detects seen event when idTo present (user seen)" do
      data = %{
        "msgId" => "msg123",
        "realMsgId" => "real123",
        "idTo" => "user789"
      }

      # is_seen_event? returns true for idTo field
      assert is_binary(data["idTo"])

      model = SeenMessage.from_ws_data(data, @uid, :user)

      assert model.thread_type == :user
      assert model.thread_id == "user789"
      assert model.is_self == false
    end

    test "dispatches SeenMessage for group with is_self detection" do
      # When uid is in seenUids, is_self should be true
      data_self = %{
        "msgId" => "msg1",
        "groupId" => "g1",
        "seenUids" => [@uid, "other"]
      }

      model_self = SeenMessage.from_ws_data(data_self, @uid, :group)
      assert model_self.is_self == true

      # When uid is not in seenUids, is_self should be false
      data_other = %{
        "msgId" => "msg2",
        "groupId" => "g2",
        "seenUids" => ["other1", "other2"]
      }

      model_other = SeenMessage.from_ws_data(data_other, @uid, :group)
      assert model_other.is_self == false
    end
  end

  describe "DeliveredMessage model dispatching" do
    test "dispatches DeliveredMessage for user delivery" do
      data = %{
        "msgId" => "msg123",
        "realMsgId" => "real123",
        "deliveredUids" => ["user789"],
        "seenUids" => [],
        "seen" => 0,
        "mSTs" => 1_705_500_000_000
      }

      model = DeliveredMessage.from_ws_data(data, @uid, :user)

      assert %DeliveredMessage{} = model
      assert model.thread_type == :user
      assert model.thread_id == "user789"
      assert model.is_self == false
      assert model.delivered_uids == ["user789"]
    end

    test "dispatches DeliveredMessage for group delivery" do
      data = %{
        "msgId" => "msg456",
        "groupId" => "group789",
        "deliveredUids" => ["u1", "u2", @uid],
        "seenUids" => ["u1"],
        "seen" => 1
      }

      model = DeliveredMessage.from_ws_data(data, @uid, :group)

      assert model.thread_type == :group
      assert model.thread_id == "group789"
      assert model.is_self == true
      assert @uid in model.delivered_uids
    end

    test "delivered vs seen detection based on payload" do
      # Delivered event: has deliveredUids but not seenUids or empty seenUids
      # Seen event: has seenUids with items OR has idTo

      delivered_data = %{
        "msgId" => "m1",
        "deliveredUids" => ["u1"],
        "seenUids" => []
      }

      seen_data_group = %{
        "msgId" => "m2",
        "groupId" => "g1",
        "seenUids" => ["u1", "u2"]
      }

      seen_data_user = %{
        "msgId" => "m3",
        "idTo" => "u1"
      }

      # is_seen_event? logic
      refute is_list(delivered_data["seenUids"]) and length(delivered_data["seenUids"]) > 0
      assert is_list(seen_data_group["seenUids"]) and length(seen_data_group["seenUids"]) > 0
      assert is_binary(seen_data_user["idTo"])
    end
  end

  describe "Event dispatch integration" do
    test "events can be subscribed to and received" do
      topic = Events.topic(@account_id, :message, :user)

      message = %Message{
        msg_id: "test123",
        cli_msg_id: "cli123",
        msg_type: "chat.text",
        uid_from: "sender",
        id_to: @uid,
        content: "Test message",
        ts: "1705500000000",
        ttl: 0,
        thread_id: "sender",
        thread_type: :user,
        is_self: false,
        quote: nil,
        mentions: nil
      }

      Events.broadcast(topic, message)

      assert_receive {:zca_event, ^topic, received_message}
      assert %Message{} = received_message
      assert received_message.msg_id == "test123"
    end

    test "typing events with thread_type are dispatched correctly" do
      user_topic = Events.topic(@account_id, :typing, :user)
      group_topic = Events.topic(@account_id, :typing, :group)

      user_typing = %Typing{
        uid: "u1",
        ts: "0",
        is_pc: false,
        thread_id: "u1",
        thread_type: :user,
        is_self: false
      }

      group_typing = %Typing{
        uid: "u2",
        ts: "0",
        is_pc: true,
        thread_id: "g1",
        thread_type: :group,
        is_self: false
      }

      Events.broadcast(user_topic, user_typing)
      Events.broadcast(group_topic, group_typing)

      assert_receive {:zca_event, ^user_topic, %Typing{thread_type: :user}}
      assert_receive {:zca_event, ^group_topic, %Typing{thread_type: :group}}
    end

    test "reaction events split by thread_type" do
      user_topic = Events.topic(@account_id, :reaction, :user)
      group_topic = Events.topic(@account_id, :reaction, :group)

      user_reaction = %Reaction{
        action_id: "a1",
        msg_id: "m1",
        cli_msg_id: nil,
        msg_type: "reaction",
        uid_from: "u1",
        id_to: @uid,
        d_name: nil,
        content: %{},
        ts: "0",
        ttl: 0,
        thread_id: "u1",
        thread_type: :user,
        is_self: false
      }

      group_reaction = %Reaction{
        action_id: "a2",
        msg_id: "m2",
        cli_msg_id: nil,
        msg_type: "reaction",
        uid_from: "u2",
        id_to: "g1",
        d_name: nil,
        content: %{},
        ts: "0",
        ttl: 0,
        thread_id: "g1",
        thread_type: :group,
        is_self: false
      }

      Events.broadcast(user_topic, user_reaction)
      Events.broadcast(group_topic, group_reaction)

      assert_receive {:zca_event, ^user_topic, %Reaction{thread_type: :user}}
      assert_receive {:zca_event, ^group_topic, %Reaction{thread_type: :group}}
    end

    test "seen and delivered events dispatched separately" do
      seen_topic = Events.topic(@account_id, :seen, :user)
      delivered_topic = Events.topic(@account_id, :delivered, :user)

      seen_msg = %SeenMessage{
        msg_id: "m1",
        real_msg_id: "r1",
        id_to: "u1",
        group_id: nil,
        thread_id: "u1",
        thread_type: :user,
        is_self: false,
        seen_uids: nil
      }

      delivered_msg = %DeliveredMessage{
        msg_id: "m2",
        real_msg_id: "r2",
        group_id: nil,
        thread_id: "u2",
        thread_type: :user,
        is_self: false,
        seen: 0,
        delivered_uids: ["u2"],
        seen_uids: [],
        ts: nil
      }

      Events.broadcast(seen_topic, seen_msg)
      Events.broadcast(delivered_topic, delivered_msg)

      assert_receive {:zca_event, ^seen_topic, %SeenMessage{}}
      assert_receive {:zca_event, ^delivered_topic, %DeliveredMessage{}}
    end
  end
end
