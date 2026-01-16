defmodule ZcaEx.Api.Endpoints.GetFriendOnlinesTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetFriendOnlines
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
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

  describe "build_params/1" do
    test "builds params with imei" do
      params = GetFriendOnlines.build_params("test-imei-123")

      assert params == %{imei: "test-imei-123"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      {:ok, url} = GetFriendOnlines.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/friend/onlines"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"profile" => "https://profile2.zalo.me"}}
      {:ok, url} = GetFriendOnlines.build_base_url(session)

      assert url =~ "https://profile2.zalo.me/api/social/friend/onlines"
    end

    test "returns error when service URL not found", %{session: session} do
      session = %{session | zpw_service_map: %{}}

      assert {:error, error} = GetFriendOnlines.build_base_url(session)
      assert error.code == :service_not_found
      assert error.message =~ "profile service URL not found"
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params in query", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetFriendOnlines.build_url("https://profile.zalo.me", encrypted, session)

      assert url =~ "https://profile.zalo.me/api/social/friend/onlines"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "parses onlines array with status JSON string" do
      data = %{
        "onlines" => [
          %{"id" => "user1", "status" => ~s({"online":true,"lastSeen":1234567890})},
          %{"id" => "user2", "status" => ~s({"online":false,"lastSeen":1234567800})}
        ]
      }

      result = GetFriendOnlines.transform_response(data)

      assert length(result.onlines) == 2
      [first, second] = result.onlines
      assert first["id"] == "user1"
      assert first["status"] == %{"online" => true, "lastSeen" => 1_234_567_890}
      assert second["id"] == "user2"
      assert second["status"] == %{"online" => false, "lastSeen" => 1_234_567_800}
    end

    test "handles status as already parsed map" do
      data = %{
        "onlines" => [
          %{"id" => "user1", "status" => %{"online" => true}}
        ]
      }

      result = GetFriendOnlines.transform_response(data)

      assert length(result.onlines) == 1
      [first] = result.onlines
      assert first["status"] == %{"online" => true}
    end

    test "handles invalid JSON in status field" do
      data = %{
        "onlines" => [
          %{"id" => "user1", "status" => "not valid json"}
        ]
      }

      result = GetFriendOnlines.transform_response(data)

      assert length(result.onlines) == 1
      [first] = result.onlines
      assert first["status"] == "not valid json"
    end

    test "handles empty onlines array" do
      data = %{"onlines" => []}

      result = GetFriendOnlines.transform_response(data)

      assert result.onlines == []
    end

    test "handles missing onlines" do
      data = %{}

      result = GetFriendOnlines.transform_response(data)

      assert result.onlines == []
    end

    test "handles nil onlines" do
      data = %{"onlines" => nil}

      result = GetFriendOnlines.transform_response(data)

      assert result.onlines == []
    end

    test "handles atom keys in response" do
      data = %{
        onlines: [
          %{id: "user1", status: ~s({"online":true})}
        ]
      }

      result = GetFriendOnlines.transform_response(data)

      assert length(result.onlines) == 1
    end
  end
end
