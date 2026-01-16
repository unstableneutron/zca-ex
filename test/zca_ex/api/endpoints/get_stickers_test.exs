defmodule ZcaEx.Api.Endpoints.GetStickersTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetStickers
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

  describe "validate_keyword/1" do
    test "returns :ok for valid keyword" do
      assert :ok = GetStickers.validate_keyword("hello")
    end

    test "returns error for empty string" do
      assert {:error, error} = GetStickers.validate_keyword("")
      assert error.message =~ "keyword is required"
    end

    test "returns error for nil" do
      assert {:error, error} = GetStickers.validate_keyword(nil)
      assert error.message =~ "keyword is required"
    end

    test "returns error for non-string" do
      assert {:error, _} = GetStickers.validate_keyword(123)
      assert {:error, _} = GetStickers.validate_keyword([])
    end

    test "returns error for whitespace-only string" do
      assert {:error, error} = GetStickers.validate_keyword("   ")
      assert error.message =~ "keyword is required"
    end

    test "accepts valid keyword with leading/trailing whitespace" do
      assert :ok = GetStickers.validate_keyword("  hello  ")
    end
  end

  describe "build_params/2" do
    test "builds correct params map", %{credentials: credentials} do
      params = GetStickers.build_params("test", credentials)

      assert params.keyword == "test"
      assert params.gif == 1
      assert params.guggy == 0
      assert params.imei == "test-imei-12345"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL from session", %{session: session} do
      url = GetStickers.build_base_url(session)

      assert url == "https://sticker.zalo.me/api/message/sticker/suggest/stickers"
    end

    test "uses default URL when sticker service not found" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      url = GetStickers.build_base_url(session)
      assert url == "https://sticker.zalo.me/api/message/sticker/suggest/stickers"
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params", %{session: session} do
      base_url = "https://sticker.zalo.me/api/message/sticker/suggest/stickers"
      url = GetStickers.build_url(base_url, "encrypted123", session)

      assert url =~ base_url
      assert url =~ "params=encrypted123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "extract_sticker_ids/1" do
    test "extracts sticker IDs from sugg_sticker array" do
      data = %{
        "sugg_sticker" => [
          %{"sticker_id" => 123, "name" => "sticker1"},
          %{"sticker_id" => 456, "name" => "sticker2"},
          %{"sticker_id" => 789, "name" => "sticker3"}
        ]
      }

      assert {:ok, [123, 456, 789]} = GetStickers.extract_sticker_ids(data)
    end

    test "returns empty list when sugg_sticker is nil" do
      assert {:ok, []} = GetStickers.extract_sticker_ids(%{})
    end

    test "returns empty list when sugg_sticker is empty" do
      assert {:ok, []} = GetStickers.extract_sticker_ids(%{"sugg_sticker" => []})
    end

    test "filters out non-integer sticker_ids" do
      data = %{
        "sugg_sticker" => [
          %{"sticker_id" => 123},
          %{"sticker_id" => "invalid"},
          %{"sticker_id" => nil},
          %{"sticker_id" => 456}
        ]
      }

      assert {:ok, [123, 456]} = GetStickers.extract_sticker_ids(data)
    end

    test "handles atom keys" do
      data = %{
        sugg_sticker: [
          %{sticker_id: 111},
          %{sticker_id: 222}
        ]
      }

      assert {:ok, [111, 222]} = GetStickers.extract_sticker_ids(data)
    end

    test "returns empty list for non-map input" do
      assert {:ok, []} = GetStickers.extract_sticker_ids(nil)
      assert {:ok, []} = GetStickers.extract_sticker_ids([])
      assert {:ok, []} = GetStickers.extract_sticker_ids("string")
    end
  end

  describe "get/3 input validation" do
    test "returns error for empty keyword", %{session: session, credentials: credentials} do
      assert {:error, error} = GetStickers.get("", session, credentials)
      assert error.message =~ "keyword is required"
    end

    test "returns error for nil keyword", %{session: session, credentials: credentials} do
      assert {:error, error} = GetStickers.get(nil, session, credentials)
      assert error.message =~ "keyword is required"
    end
  end
end
