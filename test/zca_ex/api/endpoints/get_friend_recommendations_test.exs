defmodule ZcaEx.Api.Endpoints.GetFriendRecommendationsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetFriendRecommendations
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

  describe "build_params/1" do
    test "builds params with imei" do
      params = GetFriendRecommendations.build_params("test-imei-123")

      assert params == %{imei: "test-imei-123"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      {:ok, url} = GetFriendRecommendations.build_base_url(session)

      assert url =~ "https://friend.zalo.me/api/friend/recommendsv2/list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"friend" => "https://friend2.zalo.me"}}
      {:ok, url} = GetFriendRecommendations.build_base_url(session)

      assert url =~ "https://friend2.zalo.me/api/friend/recommendsv2/list"
    end

    test "returns error when service URL not found", %{session: session} do
      session = %{session | zpw_service_map: %{}}

      assert {:error, error} = GetFriendRecommendations.build_base_url(session)
      assert error.code == :service_not_found
      assert error.message =~ "friend service URL not found"
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params in query", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetFriendRecommendations.build_url("https://friend.zalo.me", encrypted, session)

      assert url =~ "https://friend.zalo.me/api/friend/recommendsv2/list"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with all fields" do
      data = %{
        "expiredDuration" => 3600,
        "collapseMsgListConfig" => %{"enabled" => true, "maxItems" => 10},
        "recommItems" => [
          %{"userId" => "user1", "score" => 0.95},
          %{"userId" => "user2", "score" => 0.87}
        ]
      }

      result = GetFriendRecommendations.transform_response(data)

      assert result.expired_duration == 3600
      assert result.collapse_msg_list_config == %{"enabled" => true, "maxItems" => 10}
      assert length(result.recomm_items) == 2
    end

    test "handles empty recommItems" do
      data = %{
        "expiredDuration" => 3600,
        "collapseMsgListConfig" => nil,
        "recommItems" => []
      }

      result = GetFriendRecommendations.transform_response(data)

      assert result.expired_duration == 3600
      assert result.collapse_msg_list_config == nil
      assert result.recomm_items == []
    end

    test "handles missing recommItems" do
      data = %{
        "expiredDuration" => 3600,
        "collapseMsgListConfig" => %{}
      }

      result = GetFriendRecommendations.transform_response(data)

      assert result.recomm_items == []
    end

    test "handles nil values" do
      data = %{
        "expiredDuration" => nil,
        "collapseMsgListConfig" => nil,
        "recommItems" => nil
      }

      result = GetFriendRecommendations.transform_response(data)

      assert result.expired_duration == nil
      assert result.collapse_msg_list_config == nil
      assert result.recomm_items == []
    end

    test "handles atom keys in response" do
      data = %{
        expiredDuration: 7200,
        collapseMsgListConfig: %{enabled: false},
        recommItems: [%{userId: "user1"}]
      }

      result = GetFriendRecommendations.transform_response(data)

      assert result.expired_duration == 7200
      assert result.collapse_msg_list_config == %{enabled: false}
      assert result.recomm_items == [%{userId: "user1"}]
    end

    test "handles snake_case keys in response" do
      data = %{
        "expired_duration" => 1800,
        "collapse_msg_list_config" => %{"key" => "value"},
        "recomm_items" => [%{"id" => "1"}]
      }

      result = GetFriendRecommendations.transform_response(data)

      assert result.expired_duration == 1800
      assert result.collapse_msg_list_config == %{"key" => "value"}
      assert result.recomm_items == [%{"id" => "1"}]
    end
  end
end
