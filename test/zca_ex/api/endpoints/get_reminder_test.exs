defmodule ZcaEx.Api.Endpoints.GetReminderTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetReminder
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group_board" => ["https://board.zalo.me"]
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
    test "builds correct params with reminder_id and imei" do
      params = GetReminder.build_params("reminder_123", "test-imei")

      assert params == %{
               eventId: "reminder_123",
               imei: "test-imei"
             }
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetReminder.build_base_url(session)

      assert url =~ "https://board.zalo.me/api/board/topic/getReminder"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetReminder.build_url(session, encrypted)

      assert url =~ "https://board.zalo.me/api/board/topic/getReminder"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "raises when group_board service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert_raise RuntimeError, ~r/Service URL not found for group_board/, fn ->
        GetReminder.call("reminder_123", session_no_service, credentials)
      end
    end
  end
end
