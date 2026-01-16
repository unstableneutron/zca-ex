defmodule ZcaEx.Api.Endpoints.GetAutoReplyListTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetAutoReplyList
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "auto_reply" => ["https://autoreply.zalo.me"]
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
      params = GetAutoReplyList.build_params(credentials)

      assert params.version == 0
      assert params.cliLang == "vi"
    end
  end

  describe "build_url/3" do
    test "builds correct URL with encrypted params", %{session: session} do
      url = GetAutoReplyList.build_url("https://autoreply.zalo.me", session, "encrypted123")

      assert url =~ "https://autoreply.zalo.me/api/autoreply/list"
      assert url =~ "params=encrypted123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      url = GetAutoReplyList.build_url("https://autoreply2.zalo.me", session, "enc")

      assert url =~ "https://autoreply2.zalo.me/api/autoreply/list"
    end
  end

  describe "list/2" do
    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = GetAutoReplyList.list(session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "auto_reply service URL not found"
      assert error.code == :service_not_found
    end
  end
end
