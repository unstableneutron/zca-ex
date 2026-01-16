defmodule ZcaEx.Api.Endpoints.DeleteAvatarTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.DeleteAvatar
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

  describe "validate_photo_ids/1" do
    test "returns :ok for non-empty list" do
      assert :ok = DeleteAvatar.validate_photo_ids(["photo1"])
      assert :ok = DeleteAvatar.validate_photo_ids(["photo1", "photo2", "photo3"])
    end

    test "returns error for empty list" do
      assert {:error, error} = DeleteAvatar.validate_photo_ids([])
      assert error.message == "At least one photo ID is required"
    end
  end

  describe "build_params/2" do
    test "builds correct params with single photo ID" do
      params = DeleteAvatar.build_params(["photo123"], "test-imei")

      assert params.imei == "test-imei"
      assert params.delPhotos == ~s([{"photoId":"photo123"}])
    end

    test "builds correct params with multiple photo IDs" do
      params = DeleteAvatar.build_params(["photo1", "photo2", "photo3"], "test-imei")

      assert params.imei == "test-imei"
      decoded = Jason.decode!(params.delPhotos)
      assert length(decoded) == 3
      assert Enum.at(decoded, 0) == %{"photoId" => "photo1"}
      assert Enum.at(decoded, 1) == %{"photoId" => "photo2"}
      assert Enum.at(decoded, 2) == %{"photoId" => "photo3"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = DeleteAvatar.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/del-avatars"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = DeleteAvatar.build_url(session, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/del-avatars"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{
        "delPhotoIds" => ["photo1", "photo2"],
        "errMap" => %{"photo3" => "not_found"}
      }

      result = DeleteAvatar.transform_response(data)

      assert result.deleted_photo_ids == ["photo1", "photo2"]
      assert result.error_map == %{"photo3" => "not_found"}
    end

    test "transforms response with atom keys" do
      data = %{
        delPhotoIds: ["photo1"],
        errMap: %{}
      }

      result = DeleteAvatar.transform_response(data)

      assert result.deleted_photo_ids == ["photo1"]
      assert result.error_map == %{}
    end

    test "handles missing fields with defaults" do
      result = DeleteAvatar.transform_response(%{})

      assert result.deleted_photo_ids == []
      assert result.error_map == %{}
    end
  end

  describe "call/3" do
    test "accepts single photo ID string", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        DeleteAvatar.call(session_no_service, credentials, "single_photo")
      end
    end

    test "accepts list of photo IDs", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        DeleteAvatar.call(session_no_service, credentials, ["photo1", "photo2"])
      end
    end

    test "returns error for empty photo IDs list", %{session: session, credentials: credentials} do
      assert {:error, error} = DeleteAvatar.call(session, credentials, [])
      assert error.message == "At least one photo ID is required"
    end
  end
end
