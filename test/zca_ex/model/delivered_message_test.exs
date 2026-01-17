defmodule ZcaEx.Model.DeliveredMessageTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Model.DeliveredMessage

  @uid "1234567890"

  describe "from_ws_data/3 for user delivery receipts" do
    test "creates delivered message from user delivery receipt" do
      data = %{
        "msgId" => "del123",
        "realMsgId" => "msg456",
        "seen" => 1,
        "deliveredUids" => ["9876543210"],
        "seenUids" => ["9876543210"],
        "mSTs" => 1_700_000_000_000
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :user)

      assert delivered.msg_id == "del123"
      assert delivered.real_msg_id == "msg456"
      assert delivered.group_id == nil
      assert delivered.thread_id == "9876543210"
      assert delivered.thread_type == :user
      assert delivered.seen == 1
      assert delivered.delivered_uids == ["9876543210"]
      assert delivered.seen_uids == ["9876543210"]
      assert delivered.ts == 1_700_000_000_000
    end

    test "is_self is always false for user delivery receipts" do
      data = %{
        "msgId" => "del123",
        "deliveredUids" => [@uid]
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :user)

      assert delivered.is_self == false
    end

    test "thread_id is first delivered_uid for user delivery" do
      data = %{
        "msgId" => "del123",
        "deliveredUids" => ["first_uid", "second_uid"]
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :user)

      assert delivered.thread_id == "first_uid"
    end

    test "handles empty delivered_uids for user delivery" do
      data = %{
        "msgId" => "del123",
        "deliveredUids" => []
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :user)

      assert delivered.thread_id == nil
      assert delivered.delivered_uids == []
    end

    test "handles missing optional fields for user delivery" do
      data = %{
        "msgId" => "del123"
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :user)

      assert delivered.msg_id == "del123"
      assert delivered.real_msg_id == nil
      assert delivered.seen == 0
      assert delivered.delivered_uids == []
      assert delivered.seen_uids == []
      assert delivered.ts == nil
      assert delivered.thread_id == nil
    end
  end

  describe "from_ws_data/3 for group delivery receipts" do
    test "creates delivered message from group delivery receipt" do
      data = %{
        "msgId" => "del123",
        "realMsgId" => "msg456",
        "groupId" => "group789",
        "seen" => 2,
        "deliveredUids" => ["111", "222"],
        "seenUids" => ["111"],
        "mSTs" => 1_700_000_000_000
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :group)

      assert delivered.msg_id == "del123"
      assert delivered.real_msg_id == "msg456"
      assert delivered.group_id == "group789"
      assert delivered.thread_id == "group789"
      assert delivered.thread_type == :group
      assert delivered.seen == 2
      assert delivered.delivered_uids == ["111", "222"]
      assert delivered.seen_uids == ["111"]
      assert delivered.ts == 1_700_000_000_000
    end

    test "is_self is true when uid in delivered_uids for group delivery" do
      data = %{
        "msgId" => "del123",
        "groupId" => "group789",
        "deliveredUids" => ["111", @uid, "333"]
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :group)

      assert delivered.is_self == true
    end

    test "is_self is false when uid not in delivered_uids for group delivery" do
      data = %{
        "msgId" => "del123",
        "groupId" => "group789",
        "deliveredUids" => ["111", "222", "333"]
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :group)

      assert delivered.is_self == false
    end

    test "thread_id is groupId for group delivery" do
      data = %{
        "msgId" => "del123",
        "groupId" => "my_group_id",
        "deliveredUids" => ["111"]
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :group)

      assert delivered.thread_id == "my_group_id"
    end

    test "handles empty lists for group delivery" do
      data = %{
        "msgId" => "del123",
        "groupId" => "group789",
        "deliveredUids" => [],
        "seenUids" => []
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :group)

      assert delivered.delivered_uids == []
      assert delivered.seen_uids == []
      assert delivered.is_self == false
    end

    test "handles missing fields for group delivery" do
      data = %{
        "msgId" => "del123",
        "groupId" => "group789"
      }

      delivered = DeliveredMessage.from_ws_data(data, @uid, :group)

      assert delivered.msg_id == "del123"
      assert delivered.real_msg_id == nil
      assert delivered.seen == 0
      assert delivered.delivered_uids == []
      assert delivered.seen_uids == []
      assert delivered.ts == nil
    end
  end
end
