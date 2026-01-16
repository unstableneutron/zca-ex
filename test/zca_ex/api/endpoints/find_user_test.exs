defmodule ZcaEx.Api.Endpoints.FindUserTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.FindUser
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "friend" => ["https://friend.zalo.me"]
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

  describe "normalize_phone/2" do
    test "converts local Vietnamese format to international" do
      assert "84123456789" == FindUser.normalize_phone("0123456789", "vi")
    end

    test "keeps international format unchanged for Vietnamese" do
      assert "84123456789" == FindUser.normalize_phone("84123456789", "vi")
    end

    test "does not convert for non-Vietnamese language" do
      assert "0123456789" == FindUser.normalize_phone("0123456789", "en")
    end

    test "handles phone without leading zero" do
      assert "123456789" == FindUser.normalize_phone("123456789", "vi")
    end

    test "handles empty string" do
      assert "" == FindUser.normalize_phone("", "vi")
    end
  end

  describe "build_params/3" do
    test "builds correct params" do
      params = FindUser.build_params("84123456789", "test-imei", "vi")

      assert params.phone == "84123456789"
      assert params.avatar_size == 240
      assert params.language == "vi"
      assert params.imei == "test-imei"
      assert params.reqSrc == 40
    end

    test "uses provided language" do
      params = FindUser.build_params("0123456789", "test-imei", "en")

      assert params.language == "en"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = FindUser.build_base_url(session)

      assert url =~ "https://friend.zalo.me/api/friend/profile/get"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = FindUser.build_url(session, encrypted)

      assert url =~ "https://friend.zalo.me/api/friend/profile/get"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms API response to user info struct" do
      data = %{
        "userId" => "user123",
        "zaloName" => "John",
        "displayName" => "John Doe",
        "avatar" => "https://avatar.url",
        "cover" => "https://cover.url",
        "status" => "Hello world",
        "gender" => 1,
        "dob" => 19900101,
        "sdob" => "01/01",
        "globalId" => "global123",
        "bizPkg" => %{"type" => "business"}
      }

      result = FindUser.transform_response(data)

      assert result.uid == "user123"
      assert result.zalo_name == "John"
      assert result.display_name == "John Doe"
      assert result.avatar == "https://avatar.url"
      assert result.cover == "https://cover.url"
      assert result.status == "Hello world"
      assert result.gender == 1
      assert result.dob == 19900101
      assert result.sdob == "01/01"
      assert result.global_id == "global123"
      assert result.biz_pkg == %{"type" => "business"}
    end

    test "handles missing fields with defaults" do
      data = %{}

      result = FindUser.transform_response(data)

      assert result.uid == ""
      assert result.zalo_name == ""
      assert result.display_name == ""
      assert result.avatar == ""
      assert result.cover == ""
      assert result.status == ""
      assert result.gender == 0
      assert result.dob == 0
      assert result.sdob == ""
      assert result.global_id == ""
      assert result.biz_pkg == %{}
    end

    test "handles atom keys" do
      data = %{
        userId: "user123",
        zaloName: "John",
        displayName: "John Doe",
        avatar: "https://avatar.url",
        cover: "https://cover.url",
        status: "Hello world",
        gender: 1,
        dob: 19900101,
        sdob: "01/01",
        globalId: "global123",
        bizPkg: %{type: "business"}
      }

      result = FindUser.transform_response(data)

      assert result.uid == "user123"
      assert result.zalo_name == "John"
      assert result.display_name == "John Doe"
    end
  end

  describe "call/3 validation" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        FindUser.call(session_no_service, credentials, "0123456789")
      end
    end
  end
end
