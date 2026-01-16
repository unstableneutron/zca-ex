defmodule ZcaEx.Api.Endpoints.GetFriendRequestStatusTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetFriendRequestStatus
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

  describe "build_params/2" do
    test "builds params with fid and imei" do
      params = GetFriendRequestStatus.build_params("friend123", "test-imei-123")

      assert params == %{fid: "friend123", imei: "test-imei-123"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      {:ok, url} = GetFriendRequestStatus.build_base_url(session)

      assert url =~ "https://friend.zalo.me/api/friend/reqstatus"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"friend" => "https://friend2.zalo.me"}}
      {:ok, url} = GetFriendRequestStatus.build_base_url(session)

      assert url =~ "https://friend2.zalo.me/api/friend/reqstatus"
    end

    test "returns error when service URL not found", %{session: session} do
      session = %{session | zpw_service_map: %{}}

      assert {:error, error} = GetFriendRequestStatus.build_base_url(session)
      assert error.category == :api
      assert error.code == :invalid_input
      assert error.message =~ "friend service URL not found"
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params in query", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetFriendRequestStatus.build_url("https://friend.zalo.me", session, encrypted)

      assert url =~ "https://friend.zalo.me/api/friend/reqstatus"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "returns data as-is" do
      data = %{
        "addFriendPrivacy" => 1,
        "isSeenFriendReq" => true,
        "is_friend" => false,
        "is_requested" => false,
        "is_requesting" => true
      }

      result = GetFriendRequestStatus.transform_response(data)

      assert result == data
    end

    test "handles empty map" do
      result = GetFriendRequestStatus.transform_response(%{})

      assert result == %{}
    end
  end

  describe "get/3 validation" do
    test "returns error for empty friend_id", %{session: session, credentials: credentials} do
      assert {:error, error} = GetFriendRequestStatus.get("", session, credentials)
      assert error.category == :api
      assert error.code == :invalid_input
      assert error.message =~ "friend_id must be a non-empty string"
    end

    test "returns error for nil friend_id", %{session: session, credentials: credentials} do
      assert {:error, error} = GetFriendRequestStatus.get(nil, session, credentials)
      assert error.category == :api
      assert error.code == :invalid_input
      assert error.message =~ "friend_id must be a non-empty string"
    end
  end
end
