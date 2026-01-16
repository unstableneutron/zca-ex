defmodule ZcaEx.Api.Endpoints.UpdateLangTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateLang
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

  describe "normalize_language/1" do
    test "returns VI for :vi" do
      assert "VI" == UpdateLang.normalize_language(:vi)
    end

    test "returns EN for :en" do
      assert "EN" == UpdateLang.normalize_language(:en)
    end

    test "uppercases string input" do
      assert "VI" == UpdateLang.normalize_language("vi")
      assert "EN" == UpdateLang.normalize_language("en")
      assert "VI" == UpdateLang.normalize_language("Vi")
    end
  end

  describe "build_params/1" do
    test "builds correct params for :vi" do
      params = UpdateLang.build_params(:vi)

      assert params == %{language: "VI"}
    end

    test "builds correct params for :en" do
      params = UpdateLang.build_params(:en)

      assert params == %{language: "EN"}
    end

    test "builds correct params for string input" do
      params = UpdateLang.build_params("vi")

      assert params == %{language: "VI"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = UpdateLang.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/profile/updatelang"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = UpdateLang.build_url(session, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/profile/updatelang"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        UpdateLang.call(session_no_service, credentials, :vi)
      end
    end
  end
end
