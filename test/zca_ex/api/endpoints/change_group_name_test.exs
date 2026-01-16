defmodule ZcaEx.Api.Endpoints.ChangeGroupNameTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.ChangeGroupName
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

  describe "build_params/3" do
    test "builds params with valid name", %{credentials: credentials} do
      params = ChangeGroupName.build_params("New Group Name", "group123", credentials)

      assert params.grid == "group123"
      assert params.gname == "New Group Name"
      assert params.imei == "test-imei-12345"
    end

    test "builds params with empty name uses timestamp", %{credentials: credentials} do
      before_time = System.system_time(:millisecond)
      params = ChangeGroupName.build_params("", "group123", credentials)
      after_time = System.system_time(:millisecond)

      assert params.grid == "group123"
      assert params.imei == "test-imei-12345"

      timestamp = String.to_integer(params.gname)
      assert timestamp >= before_time
      assert timestamp <= after_time
    end
  end

  describe "build_url/1" do
    test "builds correct URL with session params", %{session: session} do
      url = ChangeGroupName.build_url(session)

      assert url =~ "https://group.zalo.me/api/group/updateinfo"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end
end
