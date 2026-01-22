defmodule ZcaEx.Api.Endpoints.SendCardTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SendCard
  alias ZcaEx.Account.Session
  alias ZcaEx.Account.Credentials

  setup do
    session = %Session{
      uid: "123456789",
      secret_key: Base.encode64(:crypto.strong_rand_bytes(32)),
      zpw_service_map: %{
        "file" => ["https://file.zalo.me"],
        "chat" => ["https://chat.zalo.me"],
        "group" => ["https://group.zalo.me"],
        "friend" => ["https://friend.zalo.me"]
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
    test "builds user URL with file service and message/forward path", %{session: session} do
      url = SendCard.build_url(session, :user)

      assert url =~ "https://file.zalo.me/api/message/forward"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds group URL with file service and group/forward path", %{session: session} do
      url = SendCard.build_url(session, :group)

      assert url =~ "https://file.zalo.me/api/group/forward"
    end
  end

  describe "build_params/4" do
    test "builds user params with toId and imei", %{credentials: creds} do
      options = %{user_id: "contact123", qr_code_url: "https://qr.zalo.me/abc123"}

      params = SendCard.build_params(options, "user456", :user, creds)

      assert params.toId == "user456"
      assert params.imei == creds.imei
      assert params.ttl == 0
      assert params.msgType == 6
      refute Map.has_key?(params, :grid)
      refute Map.has_key?(params, :visibility)
    end

    test "builds group params with grid and visibility", %{credentials: creds} do
      options = %{user_id: "contact123", qr_code_url: "https://qr.zalo.me/abc123"}

      params = SendCard.build_params(options, "group456", :group, creds)

      assert params.grid == "group456"
      assert params.visibility == 0
      refute Map.has_key?(params, :toId)
      refute Map.has_key?(params, :imei)
    end

    test "includes custom ttl when provided", %{credentials: creds} do
      options = %{user_id: "contact123", qr_code_url: "https://qr.zalo.me/abc123", ttl: 60000}

      params = SendCard.build_params(options, "user456", :user, creds)

      assert params.ttl == 60000
    end

    test "encodes msgInfo as JSON with contactUid and qrCodeUrl", %{credentials: creds} do
      options = %{user_id: "contact123", qr_code_url: "https://qr.zalo.me/abc123"}

      params = SendCard.build_params(options, "user456", :user, creds)

      assert is_binary(params.msgInfo)
      msg_info = Jason.decode!(params.msgInfo)
      assert msg_info["contactUid"] == "contact123"
      assert msg_info["qrCodeUrl"] == "https://qr.zalo.me/abc123"
    end

    test "clientId is a string timestamp", %{credentials: creds} do
      options = %{user_id: "contact123", qr_code_url: "https://qr.zalo.me/abc123"}

      params = SendCard.build_params(options, "user456", :user, creds)

      assert is_binary(params.clientId)
      {parsed, ""} = Integer.parse(params.clientId)
      assert parsed > 0
    end
  end

  describe "build_msg_info/1" do
    test "builds basic msg_info without phone" do
      options = %{user_id: "contact123", qr_code_url: "https://qr.zalo.me/abc123"}

      msg_info = SendCard.build_msg_info(options)

      assert msg_info.contactUid == "contact123"
      assert msg_info.qrCodeUrl == "https://qr.zalo.me/abc123"
      refute Map.has_key?(msg_info, :phone)
    end

    test "includes phone when provided" do
      options = %{
        user_id: "contact123",
        qr_code_url: "https://qr.zalo.me/abc123",
        phone_number: "+1234567890"
      }

      msg_info = SendCard.build_msg_info(options)

      assert msg_info.contactUid == "contact123"
      assert msg_info.qrCodeUrl == "https://qr.zalo.me/abc123"
      assert msg_info.phone == "+1234567890"
    end
  end

  describe "call/5 validation" do
    test "returns error for missing user_id", %{session: session, credentials: creds} do
      assert {:error, error} = SendCard.call(%{}, "recipient123", :user, session, creds)
      assert error.message =~ "user_id"
    end

    test "returns error for empty user_id", %{session: session, credentials: creds} do
      assert {:error, error} =
               SendCard.call(%{user_id: ""}, "recipient123", :user, session, creds)

      assert error.message =~ "user_id"
    end

    test "returns error for missing thread_id", %{session: session, credentials: creds} do
      assert {:error, error} = SendCard.call(%{user_id: "contact123"}, "", :user, session, creds)
      assert error.message == "Missing threadId"
    end
  end
end
