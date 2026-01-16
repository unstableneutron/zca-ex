defmodule ZcaEx.Api.Endpoints.UpdateActiveStatusTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateActiveStatus
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
    test "builds correct params for active=true" do
      params = UpdateActiveStatus.build_params(true, "test-imei")

      assert params.status == 1
      assert params.imei == "test-imei"
    end

    test "builds correct params for active=false" do
      params = UpdateActiveStatus.build_params(false, "test-imei")

      assert params.status == 0
      assert params.imei == "test-imei"
    end
  end

  describe "build_base_url/2" do
    test "builds correct base URL for active=true (ping)", %{session: session} do
      url = UpdateActiveStatus.build_base_url(session, true)

      assert url =~ "https://profile.zalo.me/api/social/profile/ping"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds correct base URL for active=false (deactive)", %{session: session} do
      url = UpdateActiveStatus.build_base_url(session, false)

      assert url =~ "https://profile.zalo.me/api/social/profile/deactive"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params for active=true", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = UpdateActiveStatus.build_url(session, true, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/profile/ping"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds URL with encrypted params for active=false", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = UpdateActiveStatus.build_url(session, false, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/profile/deactive"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        UpdateActiveStatus.call(session_no_service, credentials, true)
      end
    end
  end
end
