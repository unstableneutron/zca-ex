defmodule ZcaEx.Api.Endpoints.GetRelatedFriendGroupTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetRelatedFriendGroup
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

  describe "normalize_friend_ids/1" do
    test "wraps single string in list" do
      assert GetRelatedFriendGroup.normalize_friend_ids("friend123") == ["friend123"]
    end

    test "returns list as-is" do
      assert GetRelatedFriendGroup.normalize_friend_ids(["a", "b"]) == ["a", "b"]
    end

    test "returns empty list for invalid input" do
      assert GetRelatedFriendGroup.normalize_friend_ids(123) == []
      assert GetRelatedFriendGroup.normalize_friend_ids(nil) == []
    end
  end

  describe "validate_friend_ids/1" do
    test "returns :ok for valid list of strings" do
      assert :ok == GetRelatedFriendGroup.validate_friend_ids(["friend1", "friend2"])
    end

    test "returns :ok for single item list" do
      assert :ok == GetRelatedFriendGroup.validate_friend_ids(["friend1"])
    end

    test "returns error for empty list" do
      assert {:error, %ZcaEx.Error{message: "friend_ids must not be empty"}} =
               GetRelatedFriendGroup.validate_friend_ids([])
    end

    test "returns error when list contains empty string" do
      assert {:error, %ZcaEx.Error{message: "all friend_ids must be non-empty strings"}} =
               GetRelatedFriendGroup.validate_friend_ids(["friend1", ""])
    end

    test "returns error when list contains non-string" do
      assert {:error, %ZcaEx.Error{message: "all friend_ids must be non-empty strings"}} =
               GetRelatedFriendGroup.validate_friend_ids(["friend1", 123])
    end
  end

  describe "build_params/2" do
    test "builds params with JSON-encoded friend_ids and imei" do
      params = GetRelatedFriendGroup.build_params(["friend1", "friend2"], "test-imei")

      assert params.friend_ids == ~s(["friend1","friend2"])
      assert params.imei == "test-imei"
    end

    test "builds params with single friend_id" do
      params = GetRelatedFriendGroup.build_params(["friend1"], "test-imei")

      assert params.friend_ids == ~s(["friend1"])
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      {:ok, url} = GetRelatedFriendGroup.build_base_url(session)

      assert url =~ "https://friend.zalo.me/api/friend/group/related"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"friend" => "https://friend2.zalo.me"}}
      {:ok, url} = GetRelatedFriendGroup.build_base_url(session)

      assert url =~ "https://friend2.zalo.me/api/friend/group/related"
    end

    test "returns error when service URL not found", %{session: session} do
      session = %{session | zpw_service_map: %{}}

      assert {:error, %ZcaEx.Error{message: "friend service URL not found"}} =
               GetRelatedFriendGroup.build_base_url(session)
    end
  end

  describe "build_url/2" do
    test "builds URL without params in query", %{session: session} do
      url = GetRelatedFriendGroup.build_url("https://friend.zalo.me", session)

      assert url =~ "https://friend.zalo.me/api/friend/group/related"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms groupRelateds map" do
      data = %{
        "groupRelateds" => %{
          "friend1" => ["group1", "group2"],
          "friend2" => ["group3"]
        }
      }

      result = GetRelatedFriendGroup.transform_response(data)

      assert result.group_relateds == %{
               "friend1" => ["group1", "group2"],
               "friend2" => ["group3"]
             }
    end

    test "handles empty groupRelateds" do
      data = %{"groupRelateds" => %{}}

      result = GetRelatedFriendGroup.transform_response(data)

      assert result.group_relateds == %{}
    end

    test "handles missing groupRelateds" do
      data = %{}

      result = GetRelatedFriendGroup.transform_response(data)

      assert result.group_relateds == %{}
    end

    test "handles atom keys in response" do
      data = %{
        groupRelateds: %{"friend1" => ["group1"]}
      }

      result = GetRelatedFriendGroup.transform_response(data)

      assert result.group_relateds == %{"friend1" => ["group1"]}
    end

    test "handles snake_case keys in response" do
      data = %{
        "group_relateds" => %{"friend1" => ["group1"]}
      }

      result = GetRelatedFriendGroup.transform_response(data)

      assert result.group_relateds == %{"friend1" => ["group1"]}
    end
  end

  describe "get/3 validation" do
    test "returns error for empty string friend_id", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "all friend_ids must be non-empty strings"}} =
               GetRelatedFriendGroup.get("", session, credentials)
    end

    test "returns error for empty list", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "friend_ids must not be empty"}} =
               GetRelatedFriendGroup.get([], session, credentials)
    end

    test "returns error for list with empty string", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "all friend_ids must be non-empty strings"}} =
               GetRelatedFriendGroup.get(["valid", ""], session, credentials)
    end

    test "returns error when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert {:error, %ZcaEx.Error{message: "friend service URL not found"}} =
               GetRelatedFriendGroup.get("friend1", session_no_service, credentials)
    end
  end
end
