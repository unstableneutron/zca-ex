defmodule ZcaEx.Api.Endpoints.RejectFriendRequestTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.RejectFriendRequest
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "friend" => ["https://friend.zalo.me"]
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

  describe "validate_user_id/1" do
    test "returns :ok for valid user_id" do
      assert :ok == RejectFriendRequest.validate_user_id("user123")
    end

    test "returns error for nil user_id" do
      assert {:error, %ZcaEx.Error{message: "User ID is required"}} =
               RejectFriendRequest.validate_user_id(nil)
    end

    test "returns error for empty string" do
      assert {:error, %ZcaEx.Error{message: "User ID cannot be empty"}} =
               RejectFriendRequest.validate_user_id("")
    end

    test "returns error for non-string" do
      assert {:error, %ZcaEx.Error{message: "User ID must be a string"}} =
               RejectFriendRequest.validate_user_id(123)
    end
  end

  describe "build_params/1" do
    test "builds correct params" do
      params = RejectFriendRequest.build_params("user123")

      assert params.fid == "user123"
    end

    test "only contains fid field" do
      params = RejectFriendRequest.build_params("user456")

      assert Map.keys(params) == [:fid]
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = RejectFriendRequest.build_base_url(session)

      assert url =~ "https://friend.zalo.me/api/friend/reject"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = RejectFriendRequest.build_url(session, encrypted)

      assert url =~ "https://friend.zalo.me/api/friend/reject"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "returns error when user_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "User ID is required"}} =
               RejectFriendRequest.call(session, credentials, nil)
    end

    test "returns error when user_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "User ID cannot be empty"}} =
               RejectFriendRequest.call(session, credentials, "")
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        RejectFriendRequest.call(session_no_service, credentials, "user123")
      end
    end
  end
end
