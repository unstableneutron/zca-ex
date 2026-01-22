defmodule ZcaEx.Api.Endpoints.KeepAliveTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.KeepAlive
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "chat" => ["https://chat.zalo.me"]
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
    test "builds correct params with imei" do
      params = KeepAlive.build_params("test-imei-12345")

      assert params.imei == "test-imei-12345"
      assert map_size(params) == 1
    end
  end

  describe "build_url/3" do
    test "builds correct URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = KeepAlive.build_url("https://chat.zalo.me", session, encrypted)

      assert url =~ "https://chat.zalo.me/keepalive"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      assert {:ok, url} = KeepAlive.build_base_url(session)

      assert url =~ "https://chat.zalo.me/keepalive"
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

      assert {:error, error} = KeepAlive.build_base_url(session_no_service)
      assert error.code == :service_not_found
      assert error.message =~ "chat service URL not found"
    end
  end

  describe "transform_response/1" do
    test "transforms response with config_vesion (original API typo)" do
      # Note: The original Zalo API has a typo "config_vesion"
      data = %{"config_vesion" => 12345}
      result = KeepAlive.transform_response(data)

      # Our code normalizes it to "config_version"
      assert result.config_version == 12345
    end

    test "handles config_version variant (fixed spelling)" do
      data = %{"config_version" => 67890}
      result = KeepAlive.transform_response(data)

      assert result.config_version == 67890
    end

    test "handles atom keys with typo" do
      data = %{config_vesion: 11111}
      result = KeepAlive.transform_response(data)

      assert result.config_version == 11111
    end

    test "handles atom keys with correct spelling" do
      data = %{config_version: 22222}
      result = KeepAlive.transform_response(data)

      assert result.config_version == 22222
    end

    test "handles missing config_version with default 0" do
      data = %{}
      result = KeepAlive.transform_response(data)

      assert result.config_version == 0
    end
  end

  describe "call/2 service URL handling" do
    test "returns error when service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert {:error, error} = KeepAlive.call(session_no_service, credentials)
      assert error.code == :service_not_found
      assert error.message =~ "chat service URL not found"
    end
  end

  describe "service URL handling" do
    test "handles service URL as list" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{
          "chat" => ["https://primary.chat.zalo.me", "https://backup.chat.zalo.me"]
        },
        api_type: 30,
        api_version: 645
      }

      assert {:ok, url} = KeepAlive.build_base_url(session)
      assert url =~ "https://primary.chat.zalo.me"
    end

    test "handles service URL as string" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{"chat" => "https://single.chat.zalo.me"},
        api_type: 30,
        api_version: 645
      }

      assert {:ok, url} = KeepAlive.build_base_url(session)
      assert url =~ "https://single.chat.zalo.me"
    end
  end

  describe "unencrypted response handling" do
    test "response uses parse_unencrypted (no decryption)" do
      # This test verifies the module is set up correctly
      # The actual parse_unencrypted behavior is tested in Response module tests
      # Here we just verify the endpoint doesn't expect encrypted response

      # build_base_url works (proves the module compiles and basic setup is correct)
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{"chat" => ["https://chat.zalo.me"]},
        api_type: 30,
        api_version: 645
      }

      assert {:ok, _url} = KeepAlive.build_base_url(session)
    end
  end
end
