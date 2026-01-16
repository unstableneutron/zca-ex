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
    test "builds correct params" do
      params = LastOnline.build_params("user123", "test-imei")

      assert params.uid == "user123"
      assert params.conv_type == 1
      assert params.imei == "test-imei"
    end
  end

  describe "build_url/3" do
    test "builds correct URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = LastOnline.build_url("https://profile.zalo.me", session, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/profile/lastOnline"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      assert {:ok, url} = LastOnline.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/profile/lastOnline"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "returns error when service URL not found" do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert {:error, error} = LastOnline.build_base_url(session_no_service)
      assert error.code == :service_not_found
      assert error.message =~ "profile service URL not found"
    end
  end

  describe "transform_response/1" do
    test "transforms response with settings and lastOnline" do
      data = %{
        "settings" => %{"show_online_status" => true},
        "lastOnline" => 1234567890
      }

      result = LastOnline.transform_response(data)

      assert result.settings.show_online_status == true
      assert result.last_online == 1234567890
    end

    test "handles atom keys" do
      data = %{
        settings: %{show_online_status: false},
        lastOnline: 9876543210
      }

      result = LastOnline.transform_response(data)

      assert result.settings.show_online_status == false
      assert result.last_online == 9876543210
    end

    test "handles missing settings" do
      data = %{"lastOnline" => 1234567890}
      result = LastOnline.transform_response(data)

      assert result.settings.show_online_status == nil
      assert result.last_online == 1234567890
    end

    test "handles last_online key variant" do
      data = %{
        "settings" => %{"show_online_status" => true},
        "last_online" => 1234567890
      }

      result = LastOnline.transform_response(data)

      assert result.last_online == 1234567890
    end
  end

  describe "get/3 input validation" do
    test "returns error when user_id is empty", %{session: session, credentials: credentials} do
      assert {:error, error} = LastOnline.get("", session, credentials)
      assert error.code == :invalid_input
      assert error.message =~ "user_id must be a non-empty string"
    end

    test "returns error when user_id is nil", %{session: session, credentials: credentials} do
      assert {:error, error} = LastOnline.get(nil, session, credentials)
      assert error.code == :invalid_input
      assert error.message =~ "user_id must be a non-empty string"
    end

    test "returns error when user_id is not a string", %{session: session, credentials: credentials} do
      assert {:error, error} = LastOnline.get(123, session, credentials)
      assert error.code == :invalid_input
      assert error.message =~ "user_id must be a non-empty string"
    end

    test "returns error when service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert {:error, error} = LastOnline.get("user123", session_no_service, credentials)
      assert error.code == :service_not_found
      assert error.message =~ "profile service URL not found"
    end
  end

  describe "service URL handling" do
    test "handles service URL as list" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{"profile" => ["https://primary.zalo.me", "https://backup.zalo.me"]},
        api_type: 30,
        api_version: 645
      }

      assert {:ok, url} = LastOnline.build_base_url(session)
      assert url =~ "https://primary.zalo.me"
    end

    test "handles service URL as string" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{"profile" => "https://single.zalo.me"},
        api_type: 30,
        api_version: 645
      }

      assert {:ok, url} = LastOnline.build_base_url(session)
      assert url =~ "https://single.zalo.me"
    end
  end
end
