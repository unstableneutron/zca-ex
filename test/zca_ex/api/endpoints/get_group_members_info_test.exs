defmodule ZcaEx.Api.Endpoints.GetGroupMembersInfoTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetGroupMembersInfo
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
      assert GetGroupMembersInfo.normalize_member_ids("user123") == ["user123"]
    end

    test "keeps list as is" do
      assert GetGroupMembersInfo.normalize_member_ids(["user1", "user2"]) == ["user1", "user2"]
    end
  end

  describe "append_version_suffix/1" do
    test "appends _0 suffix if not present" do
      assert GetGroupMembersInfo.append_version_suffix("user123") == "user123_0"
    end

    test "does not append _0 suffix if already present" do
      assert GetGroupMembersInfo.append_version_suffix("user123_0") == "user123_0"
    end
  end

  describe "build_params/1" do
    test "builds correct params with version suffix" do
      params = GetGroupMembersInfo.build_params(["user1", "user2"])

      assert params == %{
               friend_pversion_map: ["user1_0", "user2_0"]
             }
    end

    test "preserves existing _0 suffix" do
      params = GetGroupMembersInfo.build_params(["user1_0", "user2"])

      assert params == %{
               friend_pversion_map: ["user1_0", "user2_0"]
             }
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL using profile service", %{session: session} do
      url = GetGroupMembersInfo.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/group/members"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetGroupMembersInfo.build_url(session, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/group/members"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "returns error when member_ids is empty list", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "member_id cannot be empty"}} =
               GetGroupMembersInfo.call([], session, credentials)
    end

    test "raises when profile service URL not found", %{session: session, credentials: credentials} do
      session_no_profile = %{session | zpw_service_map: %{"group" => ["https://groupchat.zalo.me"]}}

      assert_raise RuntimeError, ~r/Service URL not found for profile/, fn ->
        GetGroupMembersInfo.call("user123", session_no_profile, credentials)
      end
    end
  end
end
