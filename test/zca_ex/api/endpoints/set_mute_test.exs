defmodule ZcaEx.Api.Endpoints.SetMuteTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SetMute
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "profile" => ["https://profile.zalo.me"]
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

  describe "validate_thread_id/1" do
    test "returns :ok for valid thread_id" do
      assert :ok == SetMute.validate_thread_id("thread123")
    end

    test "returns error for empty string" do
      assert {:error, %ZcaEx.Error{message: "thread_id is required"}} =
               SetMute.validate_thread_id("")
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "thread_id is required"}} =
               SetMute.validate_thread_id(nil)
    end

    test "returns error for non-string" do
      assert {:error, %ZcaEx.Error{message: "thread_id must be a non-empty string"}} =
               SetMute.validate_thread_id(123)
    end
  end

  describe "action_to_value/1" do
    test "mute returns 1" do
      assert 1 == SetMute.action_to_value(:mute)
    end

    test "unmute returns 3" do
      assert 3 == SetMute.action_to_value(:unmute)
    end
  end

  describe "thread_type_to_value/1" do
    test "user returns 1" do
      assert 1 == SetMute.thread_type_to_value(:user)
    end

    test "group returns 2" do
      assert 2 == SetMute.thread_type_to_value(:group)
    end
  end

  describe "calculate_duration/2" do
    test "unmute always returns -1 regardless of duration option" do
      assert -1 == SetMute.calculate_duration(:unmute, :one_hour)
      assert -1 == SetMute.calculate_duration(:unmute, :four_hours)
      assert -1 == SetMute.calculate_duration(:unmute, :forever)
      assert -1 == SetMute.calculate_duration(:unmute, 12345)
    end

    test "mute with :forever returns -1" do
      assert -1 == SetMute.calculate_duration(:mute, :forever)
    end

    test "mute with :one_hour returns 3600" do
      assert 3600 == SetMute.calculate_duration(:mute, :one_hour)
    end

    test "mute with :four_hours returns 14400" do
      assert 14400 == SetMute.calculate_duration(:mute, :four_hours)
    end

    test "mute with custom seconds returns the value" do
      assert 7200 == SetMute.calculate_duration(:mute, 7200)
    end

    test "mute with :until_8am returns positive seconds" do
      duration = SetMute.calculate_duration(:mute, :until_8am)
      assert is_integer(duration)
      assert duration > 0
      assert duration <= 86400
    end
  end

  describe "seconds_until_8am/1" do
    test "before 8am returns seconds until 8am same day" do
      now = ~U[2024-01-15 06:30:00Z]
      seconds = SetMute.seconds_until_8am(now)
      assert seconds == 5400
    end

    test "after 8am returns seconds until 8am next day" do
      now = ~U[2024-01-15 10:00:00Z]
      seconds = SetMute.seconds_until_8am(now)
      assert seconds == 79200
    end

    test "at exactly 8am returns seconds until next 8am" do
      now = ~U[2024-01-15 08:00:00Z]
      seconds = SetMute.seconds_until_8am(now)
      assert seconds == 86400
    end
  end

  describe "build_params/5" do
    test "builds correct params for mute user" do
      params = SetMute.build_params("thread123", :user, :mute, :forever, "test-imei")

      assert params.toid == "thread123"
      assert params.action == 1
      assert params.duration == -1
      assert params.muteType == 1
      assert params.imei == "test-imei"
      assert is_integer(params.startTime)
    end

    test "builds correct params for mute group" do
      params = SetMute.build_params("group456", :group, :mute, :one_hour, "test-imei")

      assert params.toid == "group456"
      assert params.action == 1
      assert params.duration == 3600
      assert params.muteType == 2
      assert params.imei == "test-imei"
    end

    test "builds correct params for unmute" do
      params = SetMute.build_params("thread123", :user, :unmute, :one_hour, "test-imei")

      assert params.toid == "thread123"
      assert params.action == 3
      assert params.duration == -1
      assert params.muteType == 1
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = SetMute.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/profile/setmute"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/1" do
    test "builds correct URL", %{session: session} do
      url = SetMute.build_url(session)

      assert url =~ "https://profile.zalo.me/api/social/profile/setmute"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/5 validation" do
    test "returns error when thread_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "thread_id is required"}} =
               SetMute.call(session, credentials, "")
    end

    test "returns error when thread_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "thread_id is required"}} =
               SetMute.call(session, credentials, nil)
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        SetMute.call(session_no_service, credentials, "thread123")
      end
    end
  end
end
