defmodule ZcaEx.Api.Endpoints.BlockViewFeedTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.BlockViewFeed
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

  describe "build_params/3" do
    test "builds params with block? = true" do
      params = BlockViewFeed.build_params("user123", true, "test-imei-123")

      assert params == %{fid: "user123", isBlockFeed: 1, imei: "test-imei-123"}
    end

    test "builds params with block? = false" do
      params = BlockViewFeed.build_params("user123", false, "test-imei-123")

      assert params == %{fid: "user123", isBlockFeed: 0, imei: "test-imei-123"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      assert {:ok, url} = BlockViewFeed.build_base_url(session)

      assert url =~ "https://friend.zalo.me/api/friend/feed/block"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"friend" => "https://friend2.zalo.me"}}
      assert {:ok, url} = BlockViewFeed.build_base_url(session)

      assert url =~ "https://friend2.zalo.me/api/friend/feed/block"
    end

    test "returns error when service URL not found", %{session: session} do
      session = %{session | zpw_service_map: %{}}

      assert {:error, error} = BlockViewFeed.build_base_url(session)
      assert error.message == "friend service URL not found"
      assert error.code == :invalid_input
    end
  end

  describe "build_url/2" do
    test "builds URL with session params", %{session: session} do
      url = BlockViewFeed.build_url("https://friend.zalo.me", session)

      assert url =~ "https://friend.zalo.me/api/friend/feed/block"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "set/4 validation" do
    test "returns error for empty user_id", %{session: session, credentials: credentials} do
      result = BlockViewFeed.set("", true, session, credentials)

      assert {:error, error} = result
      assert error.message == "user_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil user_id", %{session: session, credentials: credentials} do
      result = BlockViewFeed.set(nil, true, session, credentials)

      assert {:error, error} = result
      assert error.message == "user_id must be a non-empty string"
    end

    test "returns error for non-string user_id", %{session: session, credentials: credentials} do
      result = BlockViewFeed.set(123, true, session, credentials)

      assert {:error, error} = result
      assert error.message == "user_id must be a non-empty string"
    end

    test "returns error for non-boolean block?", %{session: session, credentials: credentials} do
      result = BlockViewFeed.set("user123", "yes", session, credentials)

      assert {:error, error} = result
      assert error.message == "block? must be a boolean"
      assert error.code == :invalid_input
    end

    test "returns error for nil block?", %{session: session, credentials: credentials} do
      result = BlockViewFeed.set("user123", nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "block? must be a boolean"
    end

    test "returns error for integer block?", %{session: session, credentials: credentials} do
      result = BlockViewFeed.set("user123", 1, session, credentials)

      assert {:error, error} = result
      assert error.message == "block? must be a boolean"
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert {:error, error} = BlockViewFeed.set("user123", true, session_no_service, credentials)
      assert error.message == "friend service URL not found"
    end
  end
end
