defmodule ZcaEx.Api.Endpoints.LastOnlineTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.LastOnline
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

  describe "build_params/2" do
    test "builds params with user_id, conv_type, and imei" do
      params = LastOnline.build_params("user123", "test-imei-123")

      assert params == %{uid: "user123", conv_type: 1, imei: "test-imei-123"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      assert {:ok, url} = LastOnline.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/profile/lastOnline"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"profile" => "https://profile2.zalo.me"}}
      assert {:ok, url} = LastOnline.build_base_url(session)

      assert url =~ "https://profile2.zalo.me/api/social/profile/lastOnline"
    end

    test "returns error when service URL not found", %{session: session} do
      session = %{session | zpw_service_map: %{}}

      assert {:error, error} = LastOnline.build_base_url(session)
      assert error.message == "profile service URL not found"
      assert error.code == :invalid_input
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params in query", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = LastOnline.build_url("https://profile.zalo.me", session, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/profile/lastOnline"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with settings and lastOnline" do
      data = %{
        "settings" => %{"show_online_status" => true},
        "lastOnline" => 1_234_567_890
      }

      result = LastOnline.transform_response(data)

      assert result.settings.show_online_status == true
      assert result.last_online == 1_234_567_890
    end

    test "handles atom keys in response" do
      data = %{
        settings: %{show_online_status: false},
        lastOnline: 1_111_111_111
      }

      result = LastOnline.transform_response(data)

      assert result.settings.show_online_status == false
      assert result.last_online == 1_111_111_111
    end

    test "handles snake_case lastOnline key" do
      data = %{
        "settings" => %{"show_online_status" => true},
        "last_online" => 1_234_567_890
      }

      result = LastOnline.transform_response(data)

      assert result.last_online == 1_234_567_890
    end

    test "handles missing settings" do
      data = %{"lastOnline" => 1_234_567_890}

      result = LastOnline.transform_response(data)

      assert result.settings.show_online_status == nil
      assert result.last_online == 1_234_567_890
    end

    test "handles empty settings" do
      data = %{"settings" => %{}, "lastOnline" => 1_234_567_890}

      result = LastOnline.transform_response(data)

      assert result.settings.show_online_status == nil
    end
  end

  describe "get/3 validation" do
    test "returns error for empty user_id", %{session: session, credentials: credentials} do
      result = LastOnline.get("", session, credentials)

      assert {:error, error} = result
      assert error.message == "user_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil user_id", %{session: session, credentials: credentials} do
      result = LastOnline.get(nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "user_id must be a non-empty string"
    end

    test "returns error for non-string user_id", %{session: session, credentials: credentials} do
      result = LastOnline.get(123, session, credentials)

      assert {:error, error} = result
      assert error.message == "user_id must be a non-empty string"
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert {:error, error} = LastOnline.get("user123", session_no_service, credentials)
      assert error.message == "profile service URL not found"
    end
  end
end
