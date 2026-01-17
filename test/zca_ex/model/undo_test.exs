defmodule ZcaEx.Model.UndoTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Model.Undo

  @uid "1234567890"

  describe "from_ws_data/3 for user undo" do
    test "creates undo from received user undo" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "ts" => "1234567890",
        "status" => 1,
        "content" => %{"deleteMsg" => %{"msgId" => "deleted123"}},
        "ttl" => 0
      }

      undo = Undo.from_ws_data(data, @uid, :user)

      assert undo.action_id == "action123"
      assert undo.msg_id == "msg123"
      assert undo.cli_msg_id == "cli123"
      assert undo.msg_type == "chat.undo"
      assert undo.uid_from == "9876543210"
      assert undo.id_to == @uid
      assert undo.thread_id == "9876543210"
      assert undo.thread_type == :user
      assert undo.is_self == false
      assert undo.undo_msg_id == "deleted123"
    end

    test "creates undo from self-sent user undo" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "0",
        "idTo" => "9876543210",
        "ts" => "1234567890",
        "content" => %{"deleteMsg" => %{"msgId" => "deleted123"}}
      }

      undo = Undo.from_ws_data(data, @uid, :user)

      assert undo.uid_from == @uid
      assert undo.id_to == "9876543210"
      assert undo.thread_id == "9876543210"
      assert undo.is_self == true
    end

    test "normalizes idTo when it's 0" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "9876543210",
        "idTo" => "0",
        "ts" => "1234567890",
        "content" => %{}
      }

      undo = Undo.from_ws_data(data, @uid, :user)

      assert undo.id_to == @uid
    end
  end

  describe "from_ws_data/3 for group undo" do
    test "creates undo from group undo" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "9876543210",
        "idTo" => "group123",
        "ts" => "1234567890",
        "content" => %{"deleteMsg" => %{"msgId" => "deleted123"}}
      }

      undo = Undo.from_ws_data(data, @uid, :group)

      assert undo.thread_id == "group123"
      assert undo.thread_type == :group
      assert undo.is_self == false
      assert undo.undo_msg_id == "deleted123"
    end

    test "creates self-sent group undo" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "0",
        "idTo" => "group123",
        "ts" => "1234567890",
        "content" => %{"deleteMsg" => %{"msgId" => "deleted123"}}
      }

      undo = Undo.from_ws_data(data, @uid, :group)

      assert undo.uid_from == @uid
      assert undo.thread_id == "group123"
      assert undo.is_self == true
    end
  end

  describe "from_ws_data/3 content handling" do
    test "extracts undo_msg_id from nested content" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "ts" => "1234567890",
        "content" => %{
          "deleteMsg" => %{
            "msgId" => "the-deleted-msg-id",
            "globalMsgId" => 12345,
            "cliMsgId" => 67890
          }
        }
      }

      undo = Undo.from_ws_data(data, @uid, :user)

      assert undo.undo_msg_id == "the-deleted-msg-id"
      assert undo.content["deleteMsg"]["globalMsgId"] == 12345
    end

    test "handles missing deleteMsg" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "ts" => "1234567890",
        "content" => %{}
      }

      undo = Undo.from_ws_data(data, @uid, :user)

      assert undo.undo_msg_id == nil
    end

    test "handles nil content" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "ts" => "1234567890",
        "content" => nil
      }

      undo = Undo.from_ws_data(data, @uid, :user)

      assert undo.undo_msg_id == nil
      assert undo.content == %{}
    end
  end

  describe "from_ws_data/3 with optional fields" do
    test "includes d_name when present" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "dName" => "Display Name",
        "ts" => "1234567890",
        "content" => %{}
      }

      undo = Undo.from_ws_data(data, @uid, :user)

      assert undo.d_name == "Display Name"
    end

    test "d_name is nil when not present" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "ts" => "1234567890",
        "content" => %{}
      }

      undo = Undo.from_ws_data(data, @uid, :user)

      assert undo.d_name == nil
    end

    test "ttl defaults to 0 when missing" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "ts" => "1234567890",
        "content" => %{}
      }

      undo = Undo.from_ws_data(data, @uid, :user)

      assert undo.ttl == 0
    end

    test "status defaults to 0 when missing" do
      data = %{
        "actionId" => "action123",
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.undo",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "ts" => "1234567890",
        "content" => %{}
      }

      undo = Undo.from_ws_data(data, @uid, :user)

      assert undo.status == 0
    end
  end
end
