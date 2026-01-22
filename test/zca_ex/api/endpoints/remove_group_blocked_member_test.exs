defmodule ZcaEx.Api.Endpoints.RemoveGroupBlockedMemberTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.RemoveGroupBlockedMember
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

  describe "normalize_member_ids/1" do
    test "converts single string to list" do
      assert RemoveGroupBlockedMember.normalize_member_ids("user123") == ["user123"]
    end

    test "keeps list as is" do
      assert RemoveGroupBlockedMember.normalize_member_ids(["user1", "user2"]) == [
               "user1",
               "user2"
             ]
    end
  end

  describe "build_params/2" do
    test "builds correct params" do
      params = RemoveGroupBlockedMember.build_params("group123", ["user1", "user2"])

      assert params == %{
               grid: "group123",
               members: ["user1", "user2"]
             }
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL using group service", %{session: session} do
      url = RemoveGroupBlockedMember.build_base_url(session)

      assert url =~ "https://groupchat.zalo.me/api/group/blockedmems/remove"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = RemoveGroupBlockedMember.build_url(session, encrypted)

      assert url =~ "https://groupchat.zalo.me/api/group/blockedmems/remove"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/4 validation" do
    test "returns error when group_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "group_id cannot be empty", code: :invalid_input}} =
               RemoveGroupBlockedMember.call("", "user123", session, credentials)
    end

    test "returns error when group_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "group_id cannot be empty", code: :invalid_input}} =
               RemoveGroupBlockedMember.call(nil, "user123", session, credentials)
    end

    test "returns error when member_ids is empty list", %{
      session: session,
      credentials: credentials
    } do
      assert {:error, %ZcaEx.Error{message: "member_id cannot be empty", code: :invalid_input}} =
               RemoveGroupBlockedMember.call("group123", [], session, credentials)
    end

    test "raises when group service URL not found", %{session: session, credentials: credentials} do
      session_no_group = %{session | zpw_service_map: %{"profile" => ["https://profile.zalo.me"]}}

      assert_raise RuntimeError, ~r/Service URL not found for group/, fn ->
        RemoveGroupBlockedMember.call("group123", "user123", session_no_group, credentials)
      end
    end
  end
end
