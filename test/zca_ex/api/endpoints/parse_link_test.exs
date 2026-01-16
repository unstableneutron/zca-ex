defmodule ZcaEx.Api.Endpoints.ParseLinkTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.ParseLink
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
    test "builds URL with file service and parselink path", %{session: session} do
      url = ParseLink.build_url(session)

      assert url =~ "https://file.zalo.me/api/message/parselink"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_params/2" do
    test "builds params with link, version, and imei", %{credentials: creds} do
      params = ParseLink.build_params("https://example.com", creds)

      assert params.link == "https://example.com"
      assert params.version == 1
      assert params.imei == creds.imei
    end
  end

  describe "parse/3 validation" do
    test "returns error for empty link", %{session: session, credentials: creds} do
      assert {:error, error} = ParseLink.parse("", session, creds)
      assert error.message == "Missing link"
    end

    test "returns error for nil link", %{session: session, credentials: creds} do
      assert {:error, error} = ParseLink.parse(nil, session, creds)
      assert error.message == "Missing link"
    end
  end
end
