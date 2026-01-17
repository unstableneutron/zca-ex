defmodule ZcaEx.Model.ReactionTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Model.Reaction

  @uid "1234567890"

  describe "from_ws_data/3 for user reactions" do
    test "creates reaction from received user reaction" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => %{"rIcon" => "/-heart", "rType" => 5, "source" => 6},
        "ts" => "1234567890",
        "ttl" => 0
      }

      reaction = Reaction.from_ws_data(data, @uid, :user)

      assert reaction.action_id == "action123"
      assert reaction.msg_id == "msg123"
      assert reaction.cli_msg_id == "cli123"
      assert reaction.msg_type == "chat.react"
      assert reaction.uid_from == "9876543210"
      assert reaction.id_to == @uid
      assert reaction.content == %{"rIcon" => "/-heart", "rType" => 5, "source" => 6}
      assert reaction.thread_id == "9876543210"
      assert reaction.thread_type == :user
      assert reaction.is_self == false
    end

    test "creates reaction from self-sent user reaction" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "0",
        "idTo" => "9876543210",
        "content" => %{"rIcon" => "/-heart"},
        "ts" => "1234567890",
        "ttl" => 0
      }

      reaction = Reaction.from_ws_data(data, @uid, :user)

      assert reaction.uid_from == @uid
      assert reaction.id_to == "9876543210"
      assert reaction.thread_id == "9876543210"
      assert reaction.is_self == true
    end

    test "normalizes idTo when it's 0" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "9876543210",
        "idTo" => "0",
        "content" => %{},
        "ts" => "1234567890"
      }

      reaction = Reaction.from_ws_data(data, @uid, :user)

      assert reaction.id_to == @uid
    end
  end

  describe "from_ws_data/3 for group reactions" do
    test "creates reaction from group reaction" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "9876543210",
        "idTo" => "group123",
        "content" => %{"rIcon" => "/-strong"},
        "ts" => "1234567890",
        "ttl" => 0
      }

      reaction = Reaction.from_ws_data(data, @uid, :group)

      assert reaction.thread_id == "group123"
      assert reaction.thread_type == :group
      assert reaction.is_self == false
    end

    test "creates self-sent group reaction" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "0",
        "idTo" => "group123",
        "content" => %{},
        "ts" => "1234567890"
      }

      reaction = Reaction.from_ws_data(data, @uid, :group)

      assert reaction.uid_from == @uid
      assert reaction.thread_id == "group123"
      assert reaction.is_self == true
    end
  end

  describe "from_ws_data/3 content parsing" do
    test "parses JSON string content" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => ~s({"rIcon":"/-heart","rType":5}),
        "ts" => "1234567890"
      }

      reaction = Reaction.from_ws_data(data, @uid, :user)

      assert reaction.content == %{"rIcon" => "/-heart", "rType" => 5}
    end

    test "handles already parsed map content" do
      content = %{"rIcon" => "/-heart", "rType" => 5, "source" => 6}

      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => content,
        "ts" => "1234567890"
      }

      reaction = Reaction.from_ws_data(data, @uid, :user)

      assert reaction.content == content
    end

    test "returns empty map for invalid content" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => "invalid json {",
        "ts" => "1234567890"
      }

      reaction = Reaction.from_ws_data(data, @uid, :user)

      assert reaction.content == %{}
    end

    test "returns empty map for nil content" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => nil,
        "ts" => "1234567890"
      }

      reaction = Reaction.from_ws_data(data, @uid, :user)

      assert reaction.content == %{}
    end
  end

  describe "from_ws_data/3 with optional fields" do
    test "includes d_name when present" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "dName" => "Display Name",
        "content" => %{},
        "ts" => "1234567890"
      }

      reaction = Reaction.from_ws_data(data, @uid, :user)

      assert reaction.d_name == "Display Name"
    end

    test "d_name is nil when not present" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => %{},
        "ts" => "1234567890"
      }

      reaction = Reaction.from_ws_data(data, @uid, :user)

      assert reaction.d_name == nil
    end

    test "ttl defaults to 0 when missing" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.react",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => %{},
        "ts" => "1234567890"
      }

      reaction = Reaction.from_ws_data(data, @uid, :user)

      assert reaction.ttl == 0
    end
  end
end
