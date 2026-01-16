defmodule ZcaEx.Api.Endpoints.SendFriendRequestTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SendFriendRequest
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
      assert :ok == SendFriendRequest.validate_user_id("user123")
    end

    test "returns error for nil user_id" do
      assert {:error, %ZcaEx.Error{message: "User ID is required"}} =
               SendFriendRequest.validate_user_id(nil)
    end

    test "returns error for empty string" do
      assert {:error, %ZcaEx.Error{message: "User ID cannot be empty"}} =
               SendFriendRequest.validate_user_id("")
    end

    test "returns error for non-string" do
      assert {:error, %ZcaEx.Error{message: "User ID must be a string"}} =
               SendFriendRequest.validate_user_id(123)
    end
  end

  describe "build_params/4" do
    test "builds correct params with default message" do
      params = SendFriendRequest.build_params("test-imei", "user123")

      assert params.toid == "user123"
      assert params.msg == ""
      assert params.reqsrc == 30
      assert params.imei == "test-imei"
      assert params.language == "vi"
      assert params.srcParams == ~s({"uidTo":"user123"})
    end

    test "builds params with custom message" do
      params = SendFriendRequest.build_params("test-imei", "user123", "Hello!", "vi")

      assert params.msg == "Hello!"
    end

    test "builds params with custom language" do
      params = SendFriendRequest.build_params("test-imei", "user123", "", "en")

      assert params.language == "en"
    end

    test "srcParams contains correct JSON" do
      params = SendFriendRequest.build_params("test-imei", "user456")

      decoded = Jason.decode!(params.srcParams)
      assert decoded == %{"uidTo" => "user456"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = SendFriendRequest.build_base_url(session)

      assert url =~ "https://friend.zalo.me/api/friend/sendreq"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = SendFriendRequest.build_url(session, encrypted)

      assert url =~ "https://friend.zalo.me/api/friend/sendreq"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/4 validation" do
    test "returns error when user_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "User ID is required"}} =
               SendFriendRequest.call(session, credentials, nil)
    end

    test "returns error when user_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "User ID cannot be empty"}} =
               SendFriendRequest.call(session, credentials, "")
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        SendFriendRequest.call(session_no_service, credentials, "user123")
      end
    end
  end
end
