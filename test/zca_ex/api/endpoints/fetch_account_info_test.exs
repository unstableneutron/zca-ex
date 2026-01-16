defmodule ZcaEx.Api.Endpoints.FetchAccountInfoTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.FetchAccountInfo
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

  describe "build_params/0" do
    test "returns empty map" do
      params = FetchAccountInfo.build_params()
      assert params == %{}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = FetchAccountInfo.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/profile/me-v2"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = FetchAccountInfo.build_url(session, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/profile/me-v2"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{
        "userId" => "user123",
        "displayName" => "Test User",
        "avatar" => "https://avatar.zalo.me/123.jpg",
        "phoneNumber" => "+84123456789",
        "gender" => 1,
        "dob" => "1990-01-01",
        "status" => "Hello World"
      }

      result = FetchAccountInfo.transform_response(data)

      assert result.id == "user123"
      assert result.name == "Test User"
      assert result.avatar == "https://avatar.zalo.me/123.jpg"
      assert result.phone_number == "+84123456789"
      assert result.gender == 1
      assert result.dob == "1990-01-01"
      assert result.status == "Hello World"
      assert result.raw == data
    end

    test "transforms response with atom keys" do
      data = %{
        userId: "user456",
        displayName: "Atom User",
        avatar: "https://avatar.zalo.me/456.jpg",
        phoneNumber: "+84987654321",
        gender: 0,
        dob: "1995-06-15",
        status: "Status message"
      }

      result = FetchAccountInfo.transform_response(data)

      assert result.id == "user456"
      assert result.name == "Atom User"
      assert result.avatar == "https://avatar.zalo.me/456.jpg"
      assert result.phone_number == "+84987654321"
      assert result.gender == 0
      assert result.dob == "1995-06-15"
      assert result.status == "Status message"
      assert result.raw == data
    end

    test "uses zaloName as fallback for displayName" do
      data = %{
        "userId" => "user789",
        "zaloName" => "Zalo Name Fallback",
        "avatar" => nil
      }

      result = FetchAccountInfo.transform_response(data)

      assert result.id == "user789"
      assert result.name == "Zalo Name Fallback"
      assert result.avatar == nil
    end

    test "handles empty response" do
      data = %{}

      result = FetchAccountInfo.transform_response(data)

      assert result.id == nil
      assert result.name == nil
      assert result.avatar == nil
      assert result.phone_number == nil
      assert result.gender == nil
      assert result.dob == nil
      assert result.status == nil
      assert result.raw == %{}
    end

    test "handles partial response" do
      data = %{
        "userId" => "partial_user",
        "avatar" => "https://avatar.zalo.me/partial.jpg"
      }

      result = FetchAccountInfo.transform_response(data)

      assert result.id == "partial_user"
      assert result.name == nil
      assert result.avatar == "https://avatar.zalo.me/partial.jpg"
      assert result.phone_number == nil
    end
  end

  describe "call/2" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        FetchAccountInfo.call(session_no_service, credentials)
      end
    end
  end
end
