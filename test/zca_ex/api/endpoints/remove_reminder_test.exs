defmodule ZcaEx.Api.Endpoints.RemoveReminderTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.RemoveReminder
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

  describe "build_url/2" do
    test "builds correct URL for user thread type", %{session: session} do
      url = RemoveReminder.build_url(session, :user)

      assert url =~ "https://board.zalo.me/api/board/oneone/remove"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds correct URL for group thread type", %{session: session} do
      url = RemoveReminder.build_url(session, :group)

      assert url =~ "https://board.zalo.me/api/board/topic/remove"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_params/4 for user thread type" do
    test "builds correct params", %{credentials: credentials} do
      params = RemoveReminder.build_params("user123", "reminder456", credentials, [])

      assert params.uid == "user123"
      assert params.reminderId == "reminder456"
      refute Map.has_key?(params, :imei)
    end

    test "builds correct params with explicit thread type", %{credentials: credentials} do
      params =
        RemoveReminder.build_params("user123", "reminder456", credentials, thread_type: :user)

      assert params.uid == "user123"
      assert params.reminderId == "reminder456"
    end
  end

  describe "build_params/4 for group thread type" do
    test "builds correct params", %{credentials: credentials} do
      params =
        RemoveReminder.build_params("group123", "topic456", credentials, thread_type: :group)

      assert params.grid == "group123"
      assert params.topicId == "topic456"
      assert params.imei == "test-imei-12345"
    end
  end

  describe "call/5 validation" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        RemoveReminder.call("user123", "reminder456", session_no_service, credentials)
      end
    end
  end
end
