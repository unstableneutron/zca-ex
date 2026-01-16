defmodule ZcaEx.Api.Endpoints.RemoveUserFromGroupTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.RemoveUserFromGroup
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group" => ["https://group.zalo.me"]
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
    test "builds params with single member_id", %{credentials: credentials} do
      params = RemoveUserFromGroup.build_params("group123", ["user1"], credentials)

      assert params.grid == "group123"
      assert params.members == ["user1"]
      assert params.imei == "test-imei-12345"
      refute Map.has_key?(params, :memberTypes)
    end

    test "builds params with list of member_ids", %{credentials: credentials} do
      params = RemoveUserFromGroup.build_params("group123", ["user1", "user2", "user3"], credentials)

      assert params.grid == "group123"
      assert params.members == ["user1", "user2", "user3"]
      assert params.imei == "test-imei-12345"
    end
  end

  describe "build_url/1" do
    test "builds correct URL with session params", %{session: session} do
      url = RemoveUserFromGroup.build_url(session)

      assert url =~ "https://group.zalo.me/api/group/kickout"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "input validation" do
    test "returns error for empty string member_id", %{session: session, credentials: credentials} do
      result = RemoveUserFromGroup.call("group123", "", session, credentials)

      assert {:error, error} = result
      assert error.message == "member_id cannot be empty"
      assert error.code == :invalid_input
    end

    test "returns error for empty list member_id", %{session: session, credentials: credentials} do
      result = RemoveUserFromGroup.call("group123", [], session, credentials)

      assert {:error, error} = result
      assert error.message == "member_id cannot be empty"
      assert error.code == :invalid_input
    end
  end

  describe "call/4 input handling" do
    test "handles single member ID string", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        RemoveUserFromGroup.call("group123", "user1", session_no_service, credentials)
      end
    end

    test "handles list of member IDs", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        RemoveUserFromGroup.call("group123", ["user1", "user2"], session_no_service, credentials)
      end
    end
  end
end
