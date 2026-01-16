defmodule ZcaEx.Api.Endpoints.UploadProductPhotoTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UploadProductPhoto
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "file" => ["https://file.zalo.me"]
      },
      login_info: %{
        "send2me_id" => "send2me_123"
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

  describe "build_params/5" do
    test "builds correct params" do
      params = UploadProductPhoto.build_params("test.jpg", 1234567890, 1024, "imei123", "send2me_456")

      assert params.totalChunk == 1
      assert params.fileName == "test.jpg"
      assert params.clientId == 1234567890
      assert params.totalSize == 1024
      assert params.imei == "imei123"
      assert params.chunkId == 1
      assert params.toid == "send2me_456"
      assert params.featureId == 1
    end
  end

  describe "build_url/3" do
    test "builds correct URL", %{session: session} do
      url = UploadProductPhoto.build_url("https://file.zalo.me", "encrypted_params", session)

      assert url =~ "https://file.zalo.me/api/product/upload/photo"
      assert url =~ "params=encrypted_params"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "upload/4 validation" do
    test "returns error for nil image_data", %{session: session, credentials: credentials} do
      result = UploadProductPhoto.upload(session, credentials, nil)

      assert {:error, error} = result
      assert error.message == "image_data is required"
      assert error.code == :invalid_input
    end

    test "returns error for empty image_data", %{session: session, credentials: credentials} do
      result = UploadProductPhoto.upload(session, credentials, <<>>)

      assert {:error, error} = result
      assert error.message == "image_data cannot be empty"
      assert error.code == :invalid_input
    end

    test "returns error for non-binary image_data", %{session: session, credentials: credentials} do
      result = UploadProductPhoto.upload(session, credentials, 123)

      assert {:error, error} = result
      assert error.message == "image_data must be a binary"
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = UploadProductPhoto.upload(session_no_service, credentials, "image_binary")

      assert {:error, error} = result
      assert error.message =~ "file service URL not found"
      assert error.code == :service_not_found
    end
  end
end
