defmodule ZcaEx.Api.Endpoints.ReviewPendingMemberRequestTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.ReviewPendingMemberRequest
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
    test "builds params with isApprove=1 when approving" do
      params = ReviewPendingMemberRequest.build_params("group123", ["user1", "user2"], true)

      assert params.grid == "group123"
      assert params.members == ["user1", "user2"]
      assert params.isApprove == 1
    end

    test "builds params with isApprove=0 when rejecting" do
      params = ReviewPendingMemberRequest.build_params("group123", ["user1"], false)

      assert params.grid == "group123"
      assert params.members == ["user1"]
      assert params.isApprove == 0
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = ReviewPendingMemberRequest.build_base_url(session)

      assert url == "https://groupchat.zalo.me/api/group/pending-mems/review"
    end
  end

  describe "build_url/2" do
    test "builds correct URL with encrypted params", %{session: session} do
      encrypted_params = "encrypted_test_params"
      url = ReviewPendingMemberRequest.build_url(session, encrypted_params)

      assert url =~ "https://groupchat.zalo.me/api/group/pending-mems/review"
      assert url =~ "params=encrypted_test_params"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "normalize_member_ids/1" do
    test "normalizes single member_id to list" do
      assert ReviewPendingMemberRequest.normalize_member_ids("user1") == ["user1"]
    end

    test "keeps list as-is" do
      assert ReviewPendingMemberRequest.normalize_member_ids(["user1", "user2"]) == [
               "user1",
               "user2"
             ]
    end
  end

  describe "input validation" do
    test "returns error for empty string member_ids", %{session: session, credentials: credentials} do
      result = ReviewPendingMemberRequest.call("group123", "", true, session, credentials)

      assert {:error, error} = result
      assert error.message == "member_ids cannot be empty"
      assert error.code == :invalid_input
    end

    test "returns error for empty list member_ids", %{session: session, credentials: credentials} do
      result = ReviewPendingMemberRequest.call("group123", [], true, session, credentials)

      assert {:error, error} = result
      assert error.message == "member_ids cannot be empty"
      assert error.code == :invalid_input
    end

    test "returns error for non-boolean is_approve (integer)", %{
      session: session,
      credentials: credentials
    } do
      assert {:error, error} =
               ReviewPendingMemberRequest.call("group123", ["member1"], 1, session, credentials)

      assert error.code == :invalid_input
      assert error.message =~ "is_approve must be a boolean"
    end

    test "returns error for string is_approve", %{session: session, credentials: credentials} do
      assert {:error, error} =
               ReviewPendingMemberRequest.call("group123", ["member1"], "true", session, credentials)

      assert error.code == :invalid_input
      assert error.message =~ "is_approve must be a boolean"
    end

    test "returns error for atom is_approve", %{session: session, credentials: credentials} do
      assert {:error, error} =
               ReviewPendingMemberRequest.call("group123", ["member1"], :yes, session, credentials)

      assert error.code == :invalid_input
      assert error.message =~ "is_approve must be a boolean"
    end
  end

  describe "call/5 input handling" do
    test "handles single member ID string", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        ReviewPendingMemberRequest.call("group123", "user1", true, session_no_service, credentials)
      end
    end

    test "handles list of member IDs", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        ReviewPendingMemberRequest.call(
          "group123",
          ["user1", "user2"],
          false,
          session_no_service,
          credentials
        )
      end
    end
  end
end
