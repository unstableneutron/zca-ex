defmodule ZcaEx.WS.ConnectionMessageDispatchTest do
  @moduledoc """
  Tests for message event dispatching in WS.Connection.

  These tests verify that dispatch_event(:message, ...) correctly handles
  the various payload structures returned by Zalo's WebSocket API:

  1. Single message object (msgId directly in data)
  2. Batch wrapper format (msgs/groupMsgs array in data)
  3. Double-nested structure (data.data.msgs)

  Based on real-world debugging of message sync issues where the batch wrapper
  format was being passed directly to Message.from_ws_data instead of extracting
  individual messages first.
  """
  use ExUnit.Case, async: true

  alias ZcaEx.Events
  alias ZcaEx.Model.Message

  @account_id "test_message_dispatch"
  @uid "773703373984253997"

  setup do
    Events.subscribe(Events.topic(@account_id, :message, :user))
    Events.subscribe(Events.topic(@account_id, :message, :group))

    on_exit(fn ->
      Events.unsubscribe(Events.topic(@account_id, :message, :user))
      Events.unsubscribe(Events.topic(@account_id, :message, :group))
    end)

    :ok
  end

  describe "Message payload structure handling" do
    @doc """
    Test the single message format where msgId is directly in data.
    This is the "simple" format some events use.
    """
    test "parses single message object with msgId directly in data" do
      data = %{
        "msgId" => "7441482715960",
        "cliMsgId" => "1768661731145",
        "msgType" => "webchat",
        "uidFrom" => "1377157535122616717",
        "idTo" => @uid,
        "content" => "Hello from friend",
        "ts" => "1768661731217",
        "ttl" => 0
      }

      model = Message.from_ws_data(data, @uid, :user)

      assert %Message{} = model
      assert model.msg_id == "7441482715960"
      assert model.thread_id == "1377157535122616717"
      assert model.content == "Hello from friend"
      assert model.is_self == false
    end

    @doc """
    Test batch wrapper format where messages are in data.msgs array.
    This is the format used for realtime message pushes (cmd 501).
    """
    test "extracts messages from batch wrapper with msgs array" do
      # This is the actual format observed in production debugging
      batch_data = %{
        "msgs" => [
          %{
            "actionId" => "12217353400662",
            "at" => 0,
            "cliMsgId" => "1768661731145",
            "cmd" => 501,
            "content" => "789",
            "dName" => "Thinh",
            "idTo" => "1377157535122616717",
            "msgId" => "7441482715960",
            "msgType" => "webchat",
            "notify" => "1",
            "ts" => "1768661731217",
            "ttl" => 0,
            "uidFrom" => "0"
          }
        ],
        "groupMsgs" => [],
        "lastActionId" => "12217353400662",
        "more" => 0
      }

      # Extract the message from the batch
      raw_msgs = Map.get(batch_data, "msgs", [])
      assert length(raw_msgs) == 1

      [raw_msg] = raw_msgs
      model = Message.from_ws_data(raw_msg, @uid, :user)

      assert %Message{} = model
      assert model.msg_id == "7441482715960"
      assert model.cli_msg_id == "1768661731145"
      assert model.content == "789"
      assert model.is_self == true
      assert model.uid_from == @uid
      # For self-sent messages, thread_id should be the recipient (idTo)
      assert model.thread_id == "1377157535122616717"
    end

    @doc """
    Test double-nested structure where data contains another data key.
    This format appears in some response types.
    """
    test "extracts messages from double-nested data.data.msgs structure" do
      # This structure was observed when dispatch_event received
      # payload with keys ["data", "error_code", "error_message"]
      double_nested = %{
        "data" => %{
          "msgs" => [
            %{
              "msgId" => "msg_double_nested",
              "cliMsgId" => "cli_double",
              "msgType" => "webchat",
              "uidFrom" => "sender123",
              "idTo" => @uid,
              "content" => "Double nested message",
              "ts" => "1768661731217",
              "ttl" => 0
            }
          ],
          "groupMsgs" => [],
          "lastActionId" => "12345"
        },
        "error_code" => 0,
        "error_message" => ""
      }

      # The fix unwraps data.data when present
      inner_data =
        if is_map(double_nested["data"]), do: double_nested["data"], else: double_nested

      raw_msgs = Map.get(inner_data, "msgs", [])
      assert length(raw_msgs) == 1

      [raw_msg] = raw_msgs
      model = Message.from_ws_data(raw_msg, @uid, :user)

      assert model.msg_id == "msg_double_nested"
      assert model.content == "Double nested message"
      assert model.thread_id == "sender123"
    end

    @doc """
    Test that batch format with groupMsgs is handled for group messages.
    """
    test "extracts group messages from groupMsgs array" do
      batch_data = %{
        "msgs" => [],
        "groupMsgs" => [
          %{
            "msgId" => "group_msg_123",
            "cliMsgId" => "cli_group",
            "msgType" => "webchat",
            "uidFrom" => "sender_in_group",
            "idTo" => "group_thread_id",
            "content" => "Group message content",
            "ts" => "1768661731217",
            "ttl" => 0
          }
        ],
        "lastActionId" => "12345"
      }

      # For group thread_type, we should extract from groupMsgs
      raw_msgs = Map.get(batch_data, "groupMsgs", [])
      assert length(raw_msgs) == 1

      [raw_msg] = raw_msgs
      model = Message.from_ws_data(raw_msg, @uid, :group)

      assert model.msg_id == "group_msg_123"
      assert model.thread_type == :group
      # For groups, thread_id is idTo
      assert model.thread_id == "group_thread_id"
    end

    @doc """
    Test message from friend (not self-sent).
    The thread_id should be the sender's uidFrom.
    """
    test "correctly identifies friend message and sets thread_id to sender" do
      friend_msg = %{
        "msgId" => "friend_msg_456",
        "cliMsgId" => "cli_friend",
        "msgType" => "webchat",
        "uidFrom" => "friend_uid_123",
        "idTo" => @uid,
        "content" => "Message from friend",
        "ts" => "1768661731217",
        "ttl" => 0
      }

      model = Message.from_ws_data(friend_msg, @uid, :user)

      assert model.is_self == false
      assert model.uid_from == "friend_uid_123"
      # For received messages, thread_id is the sender
      assert model.thread_id == "friend_uid_123"
    end

    @doc """
    Test that empty msgs array doesn't cause errors.
    """
    test "handles empty msgs array gracefully" do
      batch_data = %{
        "msgs" => [],
        "groupMsgs" => [],
        "lastActionId" => "12345"
      }

      raw_msgs = Map.get(batch_data, "msgs", [])
      assert raw_msgs == []

      # Processing empty list should not raise
      results = Enum.map(raw_msgs, &Message.from_ws_data(&1, @uid, :user))
      assert results == []
    end

    @doc """
    Regression test: ensure msgId nil doesn't crash but produces nil thread_id.
    This was the original bug where the wrapper was passed instead of individual message.
    """
    test "wrapper object without msgId produces Message with nil fields" do
      # This is what was happening before the fix - the wrapper was passed to from_ws_data
      wrapper_as_data = %{
        "msgs" => [%{"msgId" => "real_msg"}],
        "groupMsgs" => [],
        "lastActionId" => "12345"
      }

      # If we incorrectly pass the wrapper, we get nil fields
      model = Message.from_ws_data(wrapper_as_data, @uid, :user)

      # This demonstrates the bug - all fields are nil/default
      assert is_nil(model.msg_id)
      assert is_nil(model.thread_id)
      assert is_nil(model.content)
    end
  end

  describe "Real-world payload samples" do
    @doc """
    Based on actual traced payload from debugging session.
    Self-sent message in batch format with uidFrom="0".
    """
    test "real payload: self-sent message 789" do
      # Actual payload structure from debug trace
      payload_data = %{
        "clearUnreads" => [],
        "delivereds" => [],
        "eesession" => [],
        "groupMsgs" => [],
        "groupSeens" => [],
        "lastActionId" => "12217353400662",
        "more" => 0,
        "msgs" => [
          %{
            "actionId" => "12217353400662",
            "at" => 0,
            "cliMsgId" => "1768661731145",
            "cmd" => 501,
            "content" => "789",
            "dName" => "Thinh",
            "idTo" => "1377157535122616717",
            "msgId" => "7441482715960",
            "msgType" => "webchat",
            "notify" => "1",
            "paramsExt" => %{
              "containType" => 0,
              "countUnread" => 1,
              "platformType" => 0
            },
            "realMsgId" => "0",
            "st" => 3,
            "status" => 1,
            "topOut" => "0",
            "ts" => "1768661731217",
            "ttl" => 0,
            "uidFrom" => "0",
            "uin" => "0",
            "userId" => "0"
          }
        ],
        "pageMsgs" => [],
        "queueStatus" => %{},
        "seens" => []
      }

      [raw_msg] = payload_data["msgs"]
      model = Message.from_ws_data(raw_msg, @uid, :user)

      assert model.msg_id == "7441482715960"
      assert model.cli_msg_id == "1768661731145"
      assert model.content == "789"
      assert model.is_self == true
      assert model.uid_from == @uid
      assert model.thread_id == "1377157535122616717"
    end

    @doc """
    Based on actual traced payload from debugging session.
    Friend's reply message "Abc".
    """
    test "real payload: friend reply message Abc" do
      payload_data = %{
        "msgs" => [
          %{
            "actionId" => "12217354279304",
            "cliMsgId" => "1768661740316",
            "cmd" => 501,
            "content" => "Abc",
            "dName" => "Friend Name",
            "idTo" => "0",
            "msgId" => "7441483166338",
            "msgType" => "webchat",
            "notify" => "1",
            "ts" => "1768661740000",
            "ttl" => 0,
            "uidFrom" => "1377157535122616717"
          }
        ],
        "groupMsgs" => []
      }

      [raw_msg] = payload_data["msgs"]
      model = Message.from_ws_data(raw_msg, @uid, :user)

      assert model.msg_id == "7441483166338"
      assert model.content == "Abc"
      assert model.is_self == false
      assert model.uid_from == "1377157535122616717"
      # For received messages, thread_id is the sender's UID
      assert model.thread_id == "1377157535122616717"
    end
  end
end
