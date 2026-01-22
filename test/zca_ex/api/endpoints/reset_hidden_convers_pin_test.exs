defmodule ZcaEx.Api.Endpoints.ResetHiddenConversPinTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.ResetHiddenConversPin
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "conversation" => ["https://conversation.zalo.me"]
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
      assert ResetHiddenConversPin.build_params() == %{}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      assert {:ok, url} = ResetHiddenConversPin.build_base_url(session)

      assert url =~ "https://conversation.zalo.me/api/hiddenconvers/reset"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"conversation" => "https://conversation2.zalo.me"}}
      assert {:ok, url} = ResetHiddenConversPin.build_base_url(session)

      assert url =~ "https://conversation2.zalo.me/api/hiddenconvers/reset"
    end

    test "returns error when service URL not found", %{session: session} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert {:error, error} = ResetHiddenConversPin.build_base_url(session_no_service)
      assert error.message == "conversation service URL not found"
      assert error.code == :service_not_found
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params", %{session: session} do
      url =
        ResetHiddenConversPin.build_url(
          "https://conversation.zalo.me",
          "encryptedParams123",
          session
        )

      assert url =~ "https://conversation.zalo.me/api/hiddenconvers/reset"
      assert url =~ "params=encryptedParams123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/2 validation" do
    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert {:error, error} = ResetHiddenConversPin.call(session_no_service, credentials)
      assert error.message == "conversation service URL not found"
      assert error.code == :service_not_found
    end
  end
end
