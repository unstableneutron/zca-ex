defmodule ZcaEx.Api.Endpoints.GetAllGroupsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetAllGroups
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group_poll" => ["https://grouppoll.zalo.me"]
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

  describe "build_url/1" do
    test "builds correct URL with session params", %{session: session} do
      url = GetAllGroups.build_url(session)

      assert url =~ "https://grouppoll.zalo.me/api/group/getlg/v4"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "uses group_poll service", %{session: session} do
      url = GetAllGroups.build_url(session)

      assert url =~ "grouppoll.zalo.me"
    end
  end

  describe "call/2 service URL handling" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetAllGroups.call(session_no_service, credentials)
      end
    end

    test "raises when group_poll service missing", %{session: session, credentials: credentials} do
      session_wrong_service = %{session | zpw_service_map: %{"group" => ["https://group.zalo.me"]}}

      assert_raise RuntimeError, ~r/Service URL not found for group_poll/, fn ->
        GetAllGroups.call(session_wrong_service, credentials)
      end
    end
  end
end
