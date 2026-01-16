defmodule ZcaEx.Api.Endpoints.GetGroupBlockedMemberTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetGroupBlockedMember
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group" => ["https://groupchat.zalo.me"],
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

  describe "build_params/4" do
    test "builds correct params with defaults" do
      params = GetGroupBlockedMember.build_params("group123", 1, 50, "test-imei")

      assert params == %{
               grid: "group123",
               page: 1,
               count: 50,
               imei: "test-imei"
             }
    end

    test "builds correct params with custom page and count" do
      params = GetGroupBlockedMember.build_params("group123", 3, 100, "test-imei")

      assert params == %{
               grid: "group123",
               page: 3,
               count: 100,
               imei: "test-imei"
             }
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL using group service", %{session: session} do
      url = GetGroupBlockedMember.build_base_url(session)

      assert url =~ "https://groupchat.zalo.me/api/group/blockedmems/list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetGroupBlockedMember.build_url(session, encrypted)

      assert url =~ "https://groupchat.zalo.me/api/group/blockedmems/list"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/4 validation" do
    test "returns error when group_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "group_id cannot be empty", code: :invalid_input}} =
               GetGroupBlockedMember.call("", [], session, credentials)
    end

    test "returns error when group_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "group_id cannot be empty", code: :invalid_input}} =
               GetGroupBlockedMember.call(nil, [], session, credentials)
    end

    test "raises when group service URL not found", %{session: session, credentials: credentials} do
      session_no_group = %{session | zpw_service_map: %{"profile" => ["https://profile.zalo.me"]}}

      assert_raise RuntimeError, ~r/Service URL not found for group/, fn ->
        GetGroupBlockedMember.call("group123", [], session_no_group, credentials)
      end
    end
  end
end
