defmodule ZcaEx.Api.Endpoints.InviteUserToGroupsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.InviteUserToGroups
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group" => ["https://groupchat.zalo.me"]
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
    test "builds params with correct structure", %{credentials: credentials} do
      params = InviteUserToGroups.build_params(["group1", "group2"], "user123", credentials)

      assert params.grids == ["group1", "group2"]
      assert params.member == "user123"
      assert params.memberType == -1
      assert params.srcInteraction == 2
      assert params.clientLang == "vi"
    end

    test "builds params with single group as list", %{credentials: credentials} do
      params = InviteUserToGroups.build_params(["group1"], "user123", credentials)

      assert params.grids == ["group1"]
      assert params.member == "user123"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = InviteUserToGroups.build_base_url(session)

      assert url == "https://groupchat.zalo.me/api/group/invite/multi"
    end
  end

  describe "build_url/2" do
    test "builds correct URL with encrypted params", %{session: session} do
      encrypted_params = "encrypted_test_params"
      url = InviteUserToGroups.build_url(session, encrypted_params)

      assert url =~ "https://groupchat.zalo.me/api/group/invite/multi"
      assert url =~ "params=encrypted_test_params"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "normalize_group_ids/1" do
    test "normalizes single group_id to list" do
      assert InviteUserToGroups.normalize_group_ids("group1") == ["group1"]
    end

    test "keeps list as-is" do
      assert InviteUserToGroups.normalize_group_ids(["group1", "group2"]) == ["group1", "group2"]
    end
  end

  describe "input validation" do
    test "returns error for empty string group_ids", %{session: session, credentials: credentials} do
      result = InviteUserToGroups.call("", "user123", session, credentials)

      assert {:error, error} = result
      assert error.message == "group_ids cannot be empty"
      assert error.code == :invalid_input
    end

    test "returns error for empty list group_ids", %{session: session, credentials: credentials} do
      result = InviteUserToGroups.call([], "user123", session, credentials)

      assert {:error, error} = result
      assert error.message == "group_ids cannot be empty"
      assert error.code == :invalid_input
    end

    test "returns error for empty user_id", %{session: session, credentials: credentials} do
      result = InviteUserToGroups.call(["group1"], "", session, credentials)

      assert {:error, error} = result
      assert error.message == "user_id cannot be empty"
      assert error.code == :invalid_input
    end
  end

  describe "call/4 input handling" do
    test "handles single group ID string", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        InviteUserToGroups.call("group1", "user123", session_no_service, credentials)
      end
    end

    test "handles list of group IDs", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        InviteUserToGroups.call(["group1", "group2"], "user123", session_no_service, credentials)
      end
    end
  end
end
