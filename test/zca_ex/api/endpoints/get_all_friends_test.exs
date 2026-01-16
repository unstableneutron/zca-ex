defmodule ZcaEx.Api.Endpoints.GetAllFriendsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetAllFriends
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "profile" => ["https://profile.zalo.me"]
      },
      api_type: 30,
      api_version: 645
    }

    {:ok, credentials} =
      Credentials.new(
        imei: "test-imei-12345",
        user_agent: "Mozilla/5.0 Test",
        cookies: [%{"name" => "test", "value" => "cookie"}],
        language: "vi"
      )

    {:ok, session: session, credentials: credentials}
  end

  describe "build_params/3" do
    test "builds correct default params" do
      params = GetAllFriends.build_params("test-imei")

      assert params.incInvalid == 1
      assert params.page == 1
      assert params.count == 20000
      assert params.avatar_size == 120
      assert params.actiontime == 0
      assert params.imei == "test-imei"
    end

    test "accepts custom count and page" do
      params = GetAllFriends.build_params("test-imei", 100, 5)

      assert params.count == 100
      assert params.page == 5
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetAllFriends.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/friend/getfriends"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetAllFriends.build_url(session, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/friend/getfriends"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 options" do
    test "uses default options when not provided", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetAllFriends.call(session_no_service, credentials)
      end
    end

    test "accepts custom count option", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetAllFriends.call(session_no_service, credentials, count: 50)
      end
    end
  end
end
