defmodule ZcaEx.Api.Endpoints.GetAvatarListTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetAvatarList
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

  describe "build_params/3" do
    test "builds correct default params" do
      params = GetAvatarList.build_params(1, 50, "test-imei")

      assert params.page == 1
      assert params.albumId == "0"
      assert params.count == 50
      assert params.imei == "test-imei"
    end

    test "accepts custom page and count" do
      params = GetAvatarList.build_params(5, 100, "test-imei")

      assert params.page == 5
      assert params.count == 100
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetAvatarList.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/avatar-list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetAvatarList.build_url(session, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/avatar-list"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_photo/1" do
    test "transforms photo with string keys" do
      photo = %{
        "photoId" => "123",
        "thumbnail" => "https://thumb.example.com/123",
        "url" => "https://example.com/123",
        "bkUrl" => "https://backup.example.com/123"
      }

      result = GetAvatarList.transform_photo(photo)

      assert result.photo_id == "123"
      assert result.thumbnail == "https://thumb.example.com/123"
      assert result.url == "https://example.com/123"
      assert result.backup_url == "https://backup.example.com/123"
    end

    test "transforms photo with atom keys" do
      photo = %{
        photoId: "456",
        thumbnail: "https://thumb.example.com/456",
        url: "https://example.com/456",
        bkUrl: "https://backup.example.com/456"
      }

      result = GetAvatarList.transform_photo(photo)

      assert result.photo_id == "456"
      assert result.thumbnail == "https://thumb.example.com/456"
      assert result.url == "https://example.com/456"
      assert result.backup_url == "https://backup.example.com/456"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{
        "albumId" => "album123",
        "nextPhotoId" => "next456",
        "hasMore" => 1,
        "photos" => [
          %{
            "photoId" => "p1",
            "thumbnail" => "thumb1",
            "url" => "url1",
            "bkUrl" => "bk1"
          }
        ]
      }

      result = GetAvatarList.transform_response(data)

      assert result.album_id == "album123"
      assert result.next_photo_id == "next456"
      assert result.has_more == true
      assert length(result.photos) == 1
      assert hd(result.photos).photo_id == "p1"
    end

    test "transforms response with atom keys" do
      data = %{
        albumId: "album789",
        nextPhotoId: "next000",
        hasMore: 0,
        photos: []
      }

      result = GetAvatarList.transform_response(data)

      assert result.album_id == "album789"
      assert result.next_photo_id == "next000"
      assert result.has_more == false
      assert result.photos == []
    end

    test "handles missing fields with defaults" do
      result = GetAvatarList.transform_response(%{})

      assert result.album_id == "0"
      assert result.next_photo_id == ""
      assert result.has_more == false
      assert result.photos == []
    end

    test "transforms multiple photos" do
      data = %{
        "albumId" => "0",
        "hasMore" => 1,
        "photos" => [
          %{"photoId" => "p1", "thumbnail" => "t1", "url" => "u1", "bkUrl" => "b1"},
          %{"photoId" => "p2", "thumbnail" => "t2", "url" => "u2", "bkUrl" => "b2"},
          %{"photoId" => "p3", "thumbnail" => "t3", "url" => "u3", "bkUrl" => "b3"}
        ]
      }

      result = GetAvatarList.transform_response(data)

      assert length(result.photos) == 3
      assert Enum.at(result.photos, 0).photo_id == "p1"
      assert Enum.at(result.photos, 1).photo_id == "p2"
      assert Enum.at(result.photos, 2).photo_id == "p3"
    end
  end

  describe "call/3 options" do
    test "uses default options when not provided", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetAvatarList.call(session_no_service, credentials)
      end
    end

    test "accepts custom count option", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetAvatarList.call(session_no_service, credentials, count: 100)
      end
    end

    test "accepts custom page option", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetAvatarList.call(session_no_service, credentials, page: 5)
      end
    end

    test "accepts both count and page options", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetAvatarList.call(session_no_service, credentials, count: 25, page: 3)
      end
    end
  end
end
