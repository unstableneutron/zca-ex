defmodule ZcaEx.Model.MessageTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Model.{Message, Mention}

  @uid "1234567890"

  describe "from_ws_data/3 for user messages" do
    test "creates message from received user message" do
      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.message",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => "Hello!",
        "ts" => "1234567890",
        "ttl" => 0
      }

      message = Message.from_ws_data(data, @uid, :user)

      assert message.msg_id == "msg123"
      assert message.cli_msg_id == "cli123"
      assert message.msg_type == "chat.message"
      assert message.uid_from == "9876543210"
      assert message.id_to == @uid
      assert message.content == "Hello!"
      assert message.thread_id == "9876543210"
      assert message.thread_type == :user
      assert message.is_self == false
    end

    test "creates message from self-sent user message" do
      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.message",
        "uidFrom" => "0",
        "idTo" => "9876543210",
        "content" => "Hello!",
        "ts" => "1234567890",
        "ttl" => 0
      }

      message = Message.from_ws_data(data, @uid, :user)

      assert message.uid_from == @uid
      assert message.id_to == "9876543210"
      assert message.thread_id == "9876543210"
      assert message.is_self == true
    end

    test "normalizes idTo when it's 0" do
      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.message",
        "uidFrom" => "9876543210",
        "idTo" => "0",
        "content" => "Hello!",
        "ts" => "1234567890"
      }

      message = Message.from_ws_data(data, @uid, :user)

      assert message.id_to == @uid
    end
  end

  describe "from_ws_data/3 for group messages" do
    test "creates message from group message" do
      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.message",
        "uidFrom" => "9876543210",
        "idTo" => "group123",
        "content" => "Hello group!",
        "ts" => "1234567890",
        "ttl" => 0
      }

      message = Message.from_ws_data(data, @uid, :group)

      assert message.thread_id == "group123"
      assert message.thread_type == :group
      assert message.is_self == false
    end

    test "creates self-sent group message" do
      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.message",
        "uidFrom" => "0",
        "idTo" => "group123",
        "content" => "Hello group!",
        "ts" => "1234567890"
      }

      message = Message.from_ws_data(data, @uid, :group)

      assert message.uid_from == @uid
      assert message.thread_id == "group123"
      assert message.is_self == true
    end
  end

  describe "from_ws_data/3 with mentions" do
    test "parses mentions from data" do
      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.message",
        "uidFrom" => "9876543210",
        "idTo" => "group123",
        "content" => "@user hello",
        "ts" => "1234567890",
        "mentions" => [
          %{"uid" => "111", "pos" => 0, "len" => 5, "type" => 0}
        ]
      }

      message = Message.from_ws_data(data, @uid, :group)

      assert length(message.mentions) == 1
      [mention] = message.mentions
      assert %Mention{} = mention
      assert mention.uid == "111"
      assert mention.pos == 0
      assert mention.len == 5
    end

    test "returns nil for empty mentions" do
      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.message",
        "uidFrom" => "9876543210",
        "idTo" => "group123",
        "content" => "hello",
        "ts" => "1234567890",
        "mentions" => []
      }

      message = Message.from_ws_data(data, @uid, :group)

      assert message.mentions == nil
    end
  end

  describe "from_ws_data/3 with quote" do
    test "parses quote data" do
      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.message",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => "Reply",
        "ts" => "1234567890",
        "quote" => %{
          "ownerId" => 111,
          "cliMsgId" => 456,
          "globalMsgId" => 789,
          "msg" => "Original message"
        }
      }

      message = Message.from_ws_data(data, @uid, :user)

      assert message.quote != nil
      assert message.quote["ownerId"] == "111"
      assert message.quote["msg"] == "Original message"
    end

    test "returns nil for missing quote" do
      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.message",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => "Hello",
        "ts" => "1234567890"
      }

      message = Message.from_ws_data(data, @uid, :user)

      assert message.quote == nil
    end
  end

  describe "from_ws_data/3 with map content" do
    test "preserves map content (attachment)" do
      content = %{
        "title" => "File",
        "description" => "A file",
        "href" => "https://example.com/file.pdf"
      }

      data = %{
        "msgId" => "msg123",
        "cliMsgId" => "cli123",
        "msgType" => "chat.file",
        "uidFrom" => "9876543210",
        "idTo" => @uid,
        "content" => content,
        "ts" => "1234567890"
      }

      message = Message.from_ws_data(data, @uid, :user)

      assert message.content == content
    end
  end
end
