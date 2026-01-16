defmodule ZcaEx.Api.Endpoints.DisperseGroupTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.DisperseGroup
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group" => ["https://group.zalo.me"]
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
    test "builds params with group_id and imei", %{credentials: credentials} do
      params = DisperseGroup.build_params("group123", credentials)

      assert params == %{
               grid: "group123",
               imei: "test-imei-12345"
             }
    end

    test "handles different group IDs", %{credentials: credentials} do
      params = DisperseGroup.build_params("another-group-456", credentials)

      assert params.grid == "another-group-456"
      assert params.imei == credentials.imei
    end
  end

  describe "build_url/2" do
    test "builds correct URL with session params", %{session: session} do
      url = DisperseGroup.build_url("https://group.zalo.me", session)

      assert url =~ "https://group.zalo.me/api/group/disperse"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "uses custom api_type and api_version from session" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{"group" => ["https://group.zalo.me"]},
        api_type: 31,
        api_version: 650
      }

      url = DisperseGroup.build_url("https://group.zalo.me", session)

      assert url =~ "zpw_ver=650"
      assert url =~ "zpw_type=31"
    end
  end

  describe "call/3 input validation" do
    test "returns error when service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert {:error, error} = DisperseGroup.call("group123", session_no_service, credentials)
      assert error.message =~ "Service URL not found"
    end
  end
end
