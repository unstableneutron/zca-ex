defmodule ZcaEx.Api.Endpoints.GetStickersDetailTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetStickersDetail
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "sticker" => ["https://sticker.zalo.me"]
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

  describe "validate_sticker_ids/1" do
    test "returns error for empty list" do
      result = GetStickersDetail.validate_sticker_ids([])

      assert {:error, error} = result
      assert error.message == "sticker_ids cannot be empty"
    end

    test "returns error for non-positive integers" do
      result = GetStickersDetail.validate_sticker_ids([1, 0, 3])

      assert {:error, error} = result
      assert error.message == "All sticker_ids must be positive integers"
    end

    test "returns error for negative integers" do
      result = GetStickersDetail.validate_sticker_ids([1, -5, 3])

      assert {:error, error} = result
      assert error.message == "All sticker_ids must be positive integers"
    end

    test "returns error for non-integers" do
      result = GetStickersDetail.validate_sticker_ids([1, "2", 3])

      assert {:error, error} = result
      assert error.message == "All sticker_ids must be positive integers"
    end

    test "returns :ok for valid sticker IDs" do
      assert :ok = GetStickersDetail.validate_sticker_ids([1, 2, 3])
    end

    test "returns :ok for single valid sticker ID" do
      assert :ok = GetStickersDetail.validate_sticker_ids([12345])
    end
  end

  describe "get/3 validation" do
    test "returns error for empty list", %{session: session, credentials: credentials} do
      result = GetStickersDetail.get([], session, credentials)

      assert {:error, error} = result
      assert error.message == "sticker_ids cannot be empty"
    end

    test "returns error for nil sticker_id", %{session: session, credentials: credentials} do
      result = GetStickersDetail.get(nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "sticker_ids must be an integer or list of integers"
    end

    test "returns error for invalid type", %{session: session, credentials: credentials} do
      result = GetStickersDetail.get("123", session, credentials)

      assert {:error, error} = result
      assert error.message == "sticker_ids must be an integer or list of integers"
    end
  end

  describe "build_params/1" do
    test "returns correct params map" do
      params = GetStickersDetail.build_params(12345)

      assert params == %{sid: 12345}
    end
  end

  describe "build_base_url/1" do
    test "builds correct URL with sticker service", %{session: session} do
      url = GetStickersDetail.build_base_url(session)

      assert url == "https://sticker.zalo.me/api/message/sticker/sticker_detail"
    end

    test "uses default URL when service not found" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      url = GetStickersDetail.build_base_url(session)

      assert url == "https://sticker.zalo.me/api/message/sticker/sticker_detail"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetStickersDetail.build_url(session, encrypted)

      assert url =~ "https://sticker.zalo.me/api/message/sticker/sticker_detail"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_detail/1" do
    test "transforms response with string keys" do
      data = %{
        "id" => 12345,
        "cateId" => 100,
        "type" => 1,
        "text" => "Hello",
        "uri" => "sticker://12345",
        "fkey" => "abc123",
        "status" => 1,
        "stickerUrl" => "https://sticker.zalo.me/12345.png",
        "stickerSpriteUrl" => "https://sticker.zalo.me/12345_sprite.png"
      }

      result = GetStickersDetail.transform_detail(data)

      assert result.id == 12345
      assert result.cate_id == 100
      assert result.type == 1
      assert result.text == "Hello"
      assert result.uri == "sticker://12345"
      assert result.fkey == "abc123"
      assert result.status == 1
      assert result.sticker_url == "https://sticker.zalo.me/12345.png"
      assert result.sticker_sprite_url == "https://sticker.zalo.me/12345_sprite.png"
    end

    test "transforms response with atom keys" do
      data = %{
        id: 67890,
        cate_id: 200,
        type: 2,
        text: "World",
        uri: "sticker://67890",
        fkey: "xyz789",
        status: 0,
        sticker_url: "https://sticker.zalo.me/67890.png",
        sticker_sprite_url: "https://sticker.zalo.me/67890_sprite.png"
      }

      result = GetStickersDetail.transform_detail(data)

      assert result.id == 67890
      assert result.cate_id == 200
      assert result.type == 2
      assert result.text == "World"
      assert result.uri == "sticker://67890"
      assert result.fkey == "xyz789"
      assert result.status == 0
      assert result.sticker_url == "https://sticker.zalo.me/67890.png"
      assert result.sticker_sprite_url == "https://sticker.zalo.me/67890_sprite.png"
    end

    test "handles missing optional fields" do
      data = %{"id" => 111, "cateId" => 50, "type" => 1}

      result = GetStickersDetail.transform_detail(data)

      assert result.id == 111
      assert result.cate_id == 50
      assert result.type == 1
      assert result.text == nil
      assert result.uri == nil
      assert result.fkey == nil
      assert result.status == nil
      assert result.sticker_url == nil
      assert result.sticker_sprite_url == nil
    end

    test "transforms response with camelCase atom keys" do
      data = %{
        id: 11111,
        cateId: 300,
        type: 3,
        text: "Test",
        uri: "sticker://11111",
        fkey: "fkey123",
        status: 1,
        stickerUrl: "https://sticker.zalo.me/11111.png",
        stickerSpriteUrl: "https://sticker.zalo.me/11111_sprite.png"
      }

      result = GetStickersDetail.transform_detail(data)

      assert result.id == 11111
      assert result.cate_id == 300
      assert result.type == 3
      assert result.text == "Test"
      assert result.uri == "sticker://11111"
      assert result.fkey == "fkey123"
      assert result.status == 1
      assert result.sticker_url == "https://sticker.zalo.me/11111.png"
      assert result.sticker_sprite_url == "https://sticker.zalo.me/11111_sprite.png"
    end
  end
end
