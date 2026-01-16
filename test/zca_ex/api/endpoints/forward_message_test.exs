defmodule ZcaEx.Api.Endpoints.ForwardMessageTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.ForwardMessage
  alias ZcaEx.Account.Session
  alias ZcaEx.Account.Credentials

  setup do
    session = %Session{
      uid: "123456789",
      secret_key: Base.encode64(:crypto.strong_rand_bytes(32)),
      zpw_service_map: %{
        "chat" => ["https://chat.zalo.me"],
        "group" => ["https://group.zalo.me"],
        "file" => ["https://file.zalo.me"]
      },
      api_type: 30,
      api_version: 645
    }

    {:ok, credentials} =
      Credentials.new(
        imei: "test-imei-123456",
        user_agent: "Mozilla/5.0 Test",
        cookies: [%{"name" => "test", "value" => "cookie"}]
      )

    {:ok, session: session, credentials: credentials}
  end

  describe "build_url/2" do
    test "builds user forward URL with /mforward path", %{session: session} do
      url = ForwardMessage.build_url(session, :user)

      assert url =~ "https://file.zalo.me/api/message/mforward"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds group forward URL with /mforward path", %{session: session} do
      url = ForwardMessage.build_url(session, :group)

      assert url =~ "https://file.zalo.me/api/group/mforward"
    end
  end

  describe "get_path/1" do
    test "returns /api/message/mforward for user" do
      assert ForwardMessage.get_path(:user) == "/api/message/mforward"
    end

    test "returns /api/group/mforward for group" do
      assert ForwardMessage.get_path(:group) == "/api/group/mforward"
    end
  end

  describe "get_base_url/1" do
    test "returns file service URL", %{session: session} do
      url = ForwardMessage.get_base_url(session)
      assert url == "https://file.zalo.me"
    end
  end

  describe "build_params/4" do
    test "builds params for user forward", %{credentials: creds} do
      payload = %{message: "Hello"}
      thread_ids = ["user1", "user2"]

      params = ForwardMessage.build_params(payload, thread_ids, :user, creds)

      assert params.ttl == 0
      assert params.msgType == "1"
      assert params.totalIds == 2
      assert params.imei == creds.imei
      assert length(params.toIds) == 2

      [first, second] = params.toIds
      assert first.toUid == "user1"
      assert second.toUid == "user2"
      assert first.ttl == 0
      refute Map.has_key?(params, :grids)
    end

    test "builds params for group forward", %{credentials: creds} do
      payload = %{message: "Hello group"}
      thread_ids = ["group1", "group2"]

      params = ForwardMessage.build_params(payload, thread_ids, :group, creds)

      assert params.ttl == 0
      assert params.msgType == "1"
      assert params.totalIds == 2
      assert length(params.grids) == 2

      [first, second] = params.grids
      assert first.grid == "group1"
      assert second.grid == "group2"
      refute Map.has_key?(params, :toIds)
      refute Map.has_key?(params, :imei)
    end

    test "includes custom ttl when provided", %{credentials: creds} do
      payload = %{message: "Expiring", ttl: 60000}
      thread_ids = ["user1"]

      params = ForwardMessage.build_params(payload, thread_ids, :user, creds)

      assert params.ttl == 60000
      [first] = params.toIds
      assert first.ttl == 60000
    end

    test "includes msgInfo with message", %{credentials: creds} do
      payload = %{message: "Test message"}
      thread_ids = ["user1"]

      params = ForwardMessage.build_params(payload, thread_ids, :user, creds)

      msg_info = Jason.decode!(params.msgInfo)
      assert msg_info["message"] == "Test message"
    end

    test "includes decorLog as null when no reference", %{credentials: creds} do
      payload = %{message: "Test"}
      thread_ids = ["user1"]

      params = ForwardMessage.build_params(payload, thread_ids, :user, creds)

      assert params.decorLog == "null"
    end

    test "includes reference in msgInfo when provided", %{credentials: creds} do
      payload = %{
        message: "Forwarded",
        reference: %{id: "msg123", ts: 1_700_000_000, log_src_type: 1, fw_lvl: 2}
      }

      thread_ids = ["user1"]

      params = ForwardMessage.build_params(payload, thread_ids, :user, creds)

      msg_info = Jason.decode!(params.msgInfo)
      assert msg_info["message"] == "Forwarded"
      assert msg_info["reference"]

      reference_wrapper = Jason.decode!(msg_info["reference"])
      assert reference_wrapper["type"] == 3

      reference_data = Jason.decode!(reference_wrapper["data"])
      assert reference_data["id"] == "msg123"
      assert reference_data["ts"] == 1_700_000_000
      assert reference_data["logSrcType"] == 1
      assert reference_data["fwLvl"] == 2
    end

    test "includes decorLog with fw data when reference provided", %{credentials: creds} do
      payload = %{
        message: "Forwarded",
        reference: %{id: "msg123", ts: 1_700_000_000, log_src_type: 1, fw_lvl: 2}
      }

      thread_ids = ["user1"]

      params = ForwardMessage.build_params(payload, thread_ids, :user, creds)

      decor_log = Jason.decode!(params.decorLog)
      assert decor_log["fw"]["pmsg"]["st"] == 1
      assert decor_log["fw"]["pmsg"]["ts"] == 1_700_000_000
      assert decor_log["fw"]["pmsg"]["id"] == "msg123"
      assert decor_log["fw"]["rmsg"]["st"] == 1
      assert decor_log["fw"]["rmsg"]["ts"] == 1_700_000_000
      assert decor_log["fw"]["rmsg"]["id"] == "msg123"
      assert decor_log["fw"]["fwLvl"] == 2
    end
  end

  describe "build_msg_info/1" do
    test "builds basic msg_info without reference" do
      payload = %{message: "Hello"}

      msg_info = ForwardMessage.build_msg_info(payload)

      assert msg_info == %{message: "Hello"}
    end

    test "builds msg_info with reference" do
      payload = %{
        message: "Hello",
        reference: %{id: "msg1", ts: 123, log_src_type: 1, fw_lvl: 1}
      }

      msg_info = ForwardMessage.build_msg_info(payload)

      assert msg_info.message == "Hello"
      assert msg_info.reference

      wrapper = Jason.decode!(msg_info.reference)
      assert wrapper["type"] == 3
    end
  end

  describe "build_decor_log/1" do
    test "returns nil when reference is nil" do
      assert ForwardMessage.build_decor_log(nil) == nil
    end

    test "builds decor_log structure when reference provided" do
      reference = %{id: "msg1", ts: 12345, fw_lvl: 2}

      decor_log = ForwardMessage.build_decor_log(reference)

      assert decor_log.fw.pmsg == %{st: 1, ts: 12345, id: "msg1"}
      assert decor_log.fw.rmsg == %{st: 1, ts: 12345, id: "msg1"}
      assert decor_log.fw.fwLvl == 2
    end
  end

  describe "call/5 validation" do
    test "returns error for missing message", %{session: session, credentials: creds} do
      result = ForwardMessage.call(%{}, ["user1"], :user, session, creds)

      assert {:error, error} = result
      assert error.message == "Missing message content"
    end

    test "returns error for empty message", %{session: session, credentials: creds} do
      result = ForwardMessage.call(%{message: ""}, ["user1"], :user, session, creds)

      assert {:error, error} = result
      assert error.message == "Missing message content"
    end

    test "returns error for empty thread_ids", %{session: session, credentials: creds} do
      result = ForwardMessage.call(%{message: "Hello"}, [], :user, session, creds)

      assert {:error, error} = result
      assert error.message == "Missing thread IDs"
    end

    test "returns error for nil thread_ids", %{session: session, credentials: creds} do
      result = ForwardMessage.call(%{message: "Hello"}, nil, :user, session, creds)

      assert {:error, error} = result
      assert error.message == "Missing thread IDs"
    end
  end
end
