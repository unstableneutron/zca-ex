defmodule ZcaEx.Api.Endpoints.LeaveGroupTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.LeaveGroup
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

  describe "build_params/4" do
    test "builds params with default silent=false", %{session: session, credentials: credentials} do
      params = LeaveGroup.build_params("group123", session, credentials)

      assert params.grids == ["group123"]
      assert params.imei == "test-imei-12345"
      assert params.silent == 0
      assert params.language == "vi"
    end

    test "builds params with silent=true", %{session: session, credentials: credentials} do
      params = LeaveGroup.build_params("group123", session, credentials, true)

      assert params.grids == ["group123"]
      assert params.imei == "test-imei-12345"
      assert params.silent == 1
      assert params.language == "vi"
    end
  end

  describe "build_url/1" do
    test "builds correct URL with session params", %{session: session} do
      url = LeaveGroup.build_url(session)

      assert url =~ "https://group.zalo.me/api/group/leave"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end
end
