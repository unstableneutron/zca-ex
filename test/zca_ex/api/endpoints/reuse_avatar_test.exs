defmodule ZcaEx.Api.Endpoints.ReuseAvatarTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.ReuseAvatar
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

  describe "validate_photo_id/1" do
    test "returns :ok for valid photo_id" do
      assert :ok == ReuseAvatar.validate_photo_id("photo123")
    end

    test "returns error for empty string" do
      assert {:error, %ZcaEx.Error{message: "Photo ID must be a non-empty string"}} =
               ReuseAvatar.validate_photo_id("")
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "Photo ID must be a non-empty string"}} =
               ReuseAvatar.validate_photo_id(nil)
    end

    test "returns error for non-string" do
      assert {:error, %ZcaEx.Error{message: "Photo ID must be a non-empty string"}} =
               ReuseAvatar.validate_photo_id(123)
    end
  end

  describe "build_params/2" do
    test "builds correct params" do
      params = ReuseAvatar.build_params("photo123", "test-imei")

      assert params.photoId == "photo123"
      assert params.isPostSocial == 0
      assert params.imei == "test-imei"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = ReuseAvatar.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/reuse-avatar"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = ReuseAvatar.build_url(session, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/reuse-avatar"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "returns error when photo_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Photo ID must be a non-empty string"}} =
               ReuseAvatar.call(session, credentials, "")
    end

    test "returns error when photo_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Photo ID must be a non-empty string"}} =
               ReuseAvatar.call(session, credentials, nil)
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        ReuseAvatar.call(session_no_service, credentials, "photo123")
      end
    end
  end
end
