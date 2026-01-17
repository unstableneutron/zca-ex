defmodule ZcaEx.Model.SeenMessageTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Model.SeenMessage

  @uid "1234567890"

  describe "from_ws_data/3 for user seen messages" do
    test "creates seen message from user seen receipt" do
      data = %{
        "msgId" => "seen123",
        "realMsgId" => "msg456",
        "idTo" => "9876543210"
      }

      seen = SeenMessage.from_ws_data(data, @uid, :user)

      assert seen.msg_id == "seen123"
      assert seen.real_msg_id == "msg456"
      assert seen.id_to == "9876543210"
      assert seen.group_id == nil
      assert seen.thread_id == "9876543210"
      assert seen.thread_type == :user
      assert seen.is_self == false
      assert seen.seen_uids == nil
    end

    test "is_self is always false for user seen messages" do
      data = %{
        "msgId" => "seen123",
        "realMsgId" => "msg456",
        "idTo" => @uid
      }

      seen = SeenMessage.from_ws_data(data, @uid, :user)

      assert seen.is_self == false
    end

    test "handles missing realMsgId" do
      data = %{
        "msgId" => "seen123",
        "idTo" => "9876543210"
      }

      seen = SeenMessage.from_ws_data(data, @uid, :user)

      assert seen.real_msg_id == nil
    end
  end

  describe "from_ws_data/3 for group seen messages" do
    test "creates seen message from group seen receipt" do
      data = %{
        "msgId" => "seen123",
        "groupId" => "group456",
        "seenUids" => ["111", "222", "333"]
      }

      seen = SeenMessage.from_ws_data(data, @uid, :group)

      assert seen.msg_id == "seen123"
      assert seen.real_msg_id == nil
      assert seen.id_to == nil
      assert seen.group_id == "group456"
      assert seen.thread_id == "group456"
      assert seen.thread_type == :group
      assert seen.is_self == false
      assert seen.seen_uids == ["111", "222", "333"]
    end

    test "is_self is true when current user is in seen_uids" do
      data = %{
        "msgId" => "seen123",
        "groupId" => "group456",
        "seenUids" => ["111", @uid, "333"]
      }

      seen = SeenMessage.from_ws_data(data, @uid, :group)

      assert seen.is_self == true
    end

    test "is_self is false when current user is not in seen_uids" do
      data = %{
        "msgId" => "seen123",
        "groupId" => "group456",
        "seenUids" => ["111", "222", "333"]
      }

      seen = SeenMessage.from_ws_data(data, @uid, :group)

      assert seen.is_self == false
    end

    test "handles empty seen_uids" do
      data = %{
        "msgId" => "seen123",
        "groupId" => "group456",
        "seenUids" => []
      }

      seen = SeenMessage.from_ws_data(data, @uid, :group)

      assert seen.seen_uids == []
      assert seen.is_self == false
    end

    test "handles missing seen_uids" do
      data = %{
        "msgId" => "seen123",
        "groupId" => "group456"
      }

      seen = SeenMessage.from_ws_data(data, @uid, :group)

      assert seen.seen_uids == []
      assert seen.is_self == false
    end
  end
end
