defmodule ZcaEx.Api.Endpoints.DeleteAutoReplyTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.DeleteAutoReply
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

  describe "build_params/2" do
    test "builds correct params structure", %{credentials: credentials} do
      params = DeleteAutoReply.build_params(123, credentials)

      assert params.cliLang == "vi"
      assert params.id == 123
    end
  end

  describe "build_url/2" do
    test "builds correct URL", %{session: session} do
      url = DeleteAutoReply.build_url("https://autoreply.zalo.me", session)

      assert url =~ "https://autoreply.zalo.me/api/autoreply/delete"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      url = DeleteAutoReply.build_url("https://autoreply2.zalo.me", session)

      assert url =~ "https://autoreply2.zalo.me/api/autoreply/delete"
    end
  end

  describe "delete/3 validation" do
    test "returns error for zero id", %{session: session, credentials: credentials} do
      result = DeleteAutoReply.delete(0, session, credentials)

      assert {:error, error} = result
      assert error.message == "id must be a positive integer"
      assert error.code == :invalid_input
    end

    test "returns error for negative id", %{session: session, credentials: credentials} do
      result = DeleteAutoReply.delete(-1, session, credentials)

      assert {:error, error} = result
      assert error.message == "id must be a positive integer"
    end

    test "returns error for non-integer id", %{session: session, credentials: credentials} do
      result = DeleteAutoReply.delete("123", session, credentials)

      assert {:error, error} = result
      assert error.message == "id must be a positive integer"
    end

    test "returns error for missing service URL with valid id", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = DeleteAutoReply.delete(123, session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "auto_reply service URL not found"
      assert error.code == :service_not_found
    end
  end
end
