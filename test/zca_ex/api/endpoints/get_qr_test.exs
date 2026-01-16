defmodule ZcaEx.Api.Endpoints.GetQRTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetQR
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

  describe "build_url/1" do
    test "builds URL with friend service and mget-qr path", %{session: session} do
      url = GetQR.build_url(session)

      assert url =~ "https://friend.zalo.me/api/friend/mget-qr"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_params/1" do
    test "builds params with fids array for single user" do
      params = GetQR.build_params(["user123"])

      assert params.fids == ["user123"]
    end

    test "builds params with fids array for multiple users" do
      params = GetQR.build_params(["user1", "user2", "user3"])

      assert params.fids == ["user1", "user2", "user3"]
    end
  end

  describe "get/3 validation" do
    test "returns error for empty user IDs list", %{session: session, credentials: creds} do
      assert {:error, error} = GetQR.get([], session, creds)
      assert error.message == "Missing user IDs"
    end
  end
end
