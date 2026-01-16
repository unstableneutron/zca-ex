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
    test "normalizes string to list" do
      assert GetRelatedFriendGroup.normalize_friend_ids("friend123") == ["friend123"]
    end

    test "keeps list as list" do
      assert GetRelatedFriendGroup.normalize_friend_ids(["f1", "f2"]) == ["f1", "f2"]
    end

    test "returns empty list for invalid input" do
      assert GetRelatedFriendGroup.normalize_friend_ids(123) == []
      assert GetRelatedFriendGroup.normalize_friend_ids(nil) == []
    end
  end

  describe "validate_friend_ids/1" do
    test "returns :ok for valid list" do
      assert :ok = GetRelatedFriendGroup.validate_friend_ids(["friend123"])
      assert :ok = GetRelatedFriendGroup.validate_friend_ids(["f1", "f2", "f3"])
    end

    test "returns error for empty list" do
      assert {:error, error} = GetRelatedFriendGroup.validate_friend_ids([])
      assert error.message == "friend_ids must not be empty"
      assert error.code == :invalid_input
    end

    test "returns error for list with empty strings" do
      assert {:error, error} = GetRelatedFriendGroup.validate_friend_ids(["f1", ""])
      assert error.message == "all friend_ids must be non-empty strings"
      assert error.code == :invalid_input
    end

    test "returns error for list with non-string elements" do
      assert {:error, error} = GetRelatedFriendGroup.validate_friend_ids(["f1", 123])
      assert error.message == "all friend_ids must be non-empty strings"
      assert error.code == :invalid_input
    end
  end

  describe "build_params/2" do
    test "builds correct params with JSON-encoded friend_ids" do
      {:ok, params} = GetRelatedFriendGroup.build_params(["friend1", "friend2"], "test-imei")

      assert params.friend_ids == ~s(["friend1","friend2"])
      assert params.imei == "test-imei"
    end

    test "builds params for single friend_id" do
      {:ok, params} = GetRelatedFriendGroup.build_params(["friend123"], "test-imei")

      assert params.friend_ids == ~s(["friend123"])
      assert params.imei == "test-imei"
    end
  end

  describe "build_url/2" do
    test "builds correct URL", %{session: session} do
      url = GetRelatedFriendGroup.build_url("https://friend.zalo.me", session)

      assert url =~ "https://friend.zalo.me/api/friend/group/related"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
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

      assert {:error, error} = GetRelatedFriendGroup.build_base_url(session)
      assert error.message =~ "friend service URL not found"
      assert error.code == :service_not_found
    end
  end

  describe "get/3 validation" do
    test "returns error for empty friend_ids list", %{session: session, credentials: credentials} do
      result = GetRelatedFriendGroup.get([], session, credentials)

      assert {:error, error} = result
      assert error.message == "friend_ids must not be empty"
      assert error.code == :invalid_input
    end

    test "returns error for invalid friend_ids", %{session: session, credentials: credentials} do
      result = GetRelatedFriendGroup.get(123, session, credentials)

      assert {:error, error} = result
      assert error.message == "friend_ids must not be empty"
      assert error.code == :invalid_input
    end

    test "returns error for list with invalid elements", %{
      session: session,
      credentials: credentials
    } do
      result = GetRelatedFriendGroup.get(["valid", ""], session, credentials)

      assert {:error, error} = result
      assert error.message == "all friend_ids must be non-empty strings"
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = GetRelatedFriendGroup.get("friend123", session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "friend service URL not found"
      assert error.code == :service_not_found
    end
  end

  describe "transform_response/1" do
    test "transforms groupRelateds from response" do
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

    test "handles atom key groupRelateds" do
      data = %{
        groupRelateds: %{"friend1" => ["group1"]}
      }

      result = GetRelatedFriendGroup.transform_response(data)

      assert result.group_relateds == %{"friend1" => ["group1"]}
    end

    test "handles snake_case group_relateds" do
      data = %{
        "group_relateds" => %{"friend1" => ["group1"]}
      }

      result = GetRelatedFriendGroup.transform_response(data)

      assert result.group_relateds == %{"friend1" => ["group1"]}
    end

    test "handles missing groupRelateds" do
      result = GetRelatedFriendGroup.transform_response(%{})

      assert result.group_relateds == %{}
    end

    test "handles empty groupRelateds" do
      data = %{"groupRelateds" => %{}}

      result = GetRelatedFriendGroup.transform_response(data)

      assert result.group_relateds == %{}
    end
  end
end
