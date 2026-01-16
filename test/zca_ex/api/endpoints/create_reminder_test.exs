defmodule ZcaEx.Api.Endpoints.CreateReminderTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.CreateReminder
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

  describe "validate_thread_type/1" do
    test "returns :ok for :user" do
      assert :ok == CreateReminder.validate_thread_type(:user)
    end

    test "returns :ok for :group" do
      assert :ok == CreateReminder.validate_thread_type(:group)
    end

    test "returns error for invalid thread_type" do
      assert {:error, %ZcaEx.Error{message: "thread_type must be :user or :group"}} =
               CreateReminder.validate_thread_type(:invalid)
    end
  end

  describe "build_url/2" do
    test "builds correct URL for user thread type", %{session: session} do
      url = CreateReminder.build_url(session, :user)

      assert url =~ "https://board.zalo.me/api/board/oneone/create"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds correct URL for group thread type", %{session: session} do
      url = CreateReminder.build_url(session, :group)

      assert url =~ "https://board.zalo.me/api/board/topic/createv2"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_params/5 for user thread type" do
    test "builds correct params with defaults", %{session: session, credentials: credentials} do
      {:ok, params} = CreateReminder.build_params("user123", "Test Reminder", session, credentials, [])

      assert Map.has_key?(params, :objectData)
      assert params.imei == "test-imei-12345"

      object_data = Jason.decode!(params.objectData)
      assert object_data["toUid"] == "user123"
      assert object_data["type"] == 0
      assert object_data["color"] == -16_245_706
      assert object_data["emoji"] == "⏰"
      assert is_integer(object_data["startTime"])
      assert object_data["duration"] == -1
      assert object_data["params"]["title"] == "Test Reminder"
      assert object_data["needPin"] == false
      assert object_data["repeat"] == 0
      assert object_data["creatorUid"] == "123456"
      assert object_data["src"] == 1
    end

    test "builds params with custom options", %{session: session, credentials: credentials} do
      start_time = 1_700_000_000_000

      {:ok, params} =
        CreateReminder.build_params("user123", "Custom Reminder", session, credentials,
          thread_type: :user,
          emoji: "🎉",
          start_time: start_time,
          repeat: 1
        )

      object_data = Jason.decode!(params.objectData)
      assert object_data["emoji"] == "🎉"
      assert object_data["startTime"] == start_time
      assert object_data["repeat"] == 1
    end
  end

  describe "build_params/5 for group thread type" do
    test "builds correct params with defaults", %{session: session, credentials: credentials} do
      {:ok, params} =
        CreateReminder.build_params("group123", "Group Reminder", session, credentials,
          thread_type: :group
        )

      assert params.grid == "group123"
      assert params.type == 0
      assert params.color == -16_245_706
      assert params.emoji == "⏰"
      assert is_integer(params.startTime)
      assert params.duration == -1
      assert params.repeat == 0
      assert params.src == 1
      assert params.imei == "test-imei-12345"
      assert params.pinAct == 0

      title_params = Jason.decode!(params.params)
      assert title_params["title"] == "Group Reminder"
    end

    test "builds params with custom options", %{session: session, credentials: credentials} do
      start_time = 1_700_000_000_000

      {:ok, params} =
        CreateReminder.build_params("group123", "Custom Group Reminder", session, credentials,
          thread_type: :group,
          emoji: "📅",
          start_time: start_time,
          repeat: 2
        )

      assert params.emoji == "📅"
      assert params.startTime == start_time
      assert params.repeat == 2
    end
  end

  describe "call/5 validation" do
    test "returns error for invalid thread_type", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "thread_type must be :user or :group"}} =
               CreateReminder.call("user123", "Test", session, credentials, thread_type: :invalid)
    end
  end
end
