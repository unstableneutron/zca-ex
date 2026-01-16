defmodule ZcaEx.Api.Endpoints.GetQuickMessageListTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetQuickMessageList
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "quick_message" => ["https://quickmsg.zalo.me"]
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

  describe "build_params/1" do
    test "builds correct params structure", %{credentials: credentials} do
      params = GetQuickMessageList.build_params(credentials)

      assert params.version == 0
      assert params.lang == 0
      assert params.imei == "test-imei-12345"
    end
  end

  describe "build_url/3" do
    test "builds correct URL with encrypted params", %{session: session} do
      url = GetQuickMessageList.build_url("https://quickmsg.zalo.me", session, "encrypted123")

      assert url =~ "https://quickmsg.zalo.me/api/quickmessage/list"
      assert url =~ "params=encrypted123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "list/2" do
    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = GetQuickMessageList.list(session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "quick_message service URL not found"
      assert error.code == :service_not_found
    end
  end
end
