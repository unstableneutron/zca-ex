defmodule ZcaEx.Api.Endpoints.GetMuteTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetMute
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

  describe "build_params/1" do
    test "builds correct params with imei" do
      params = GetMute.build_params("test-imei")

      assert params == %{imei: "test-imei"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetMute.build_base_url(session)

      assert url =~ "https://profile.zalo.me/api/social/profile/getmute"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetMute.build_url(session, encrypted)

      assert url =~ "https://profile.zalo.me/api/social/profile/getmute"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{
        "chatEntries" => [
          %{
            "id" => "user123",
            "duration" => 3600,
            "startTime" => 1_700_000_000,
            "systemTime" => 1_700_000_001,
            "currentTime" => 1_700_000_002,
            "muteMode" => 1
          }
        ],
        "groupChatEntries" => [
          %{
            "id" => "group456",
            "duration" => 7200,
            "startTime" => 1_700_100_000,
            "systemTime" => 1_700_100_001,
            "currentTime" => 1_700_100_002,
            "muteMode" => 2
          }
        ]
      }

      result = GetMute.transform_response(data)

      assert length(result.chat_entries) == 1
      assert length(result.group_chat_entries) == 1

      [chat_entry] = result.chat_entries
      assert chat_entry.id == "user123"
      assert chat_entry.duration == 3600
      assert chat_entry.start_time == 1_700_000_000
      assert chat_entry.system_time == 1_700_000_001
      assert chat_entry.current_time == 1_700_000_002
      assert chat_entry.mute_mode == 1

      [group_entry] = result.group_chat_entries
      assert group_entry.id == "group456"
      assert group_entry.duration == 7200
      assert group_entry.mute_mode == 2
    end

    test "transforms response with atom keys" do
      data = %{
        chatEntries: [
          %{
            id: "user123",
            duration: 3600,
            startTime: 1_700_000_000,
            systemTime: 1_700_000_001,
            currentTime: 1_700_000_002,
            muteMode: 1
          }
        ],
        groupChatEntries: []
      }

      result = GetMute.transform_response(data)

      assert length(result.chat_entries) == 1
      assert result.group_chat_entries == []

      [chat_entry] = result.chat_entries
      assert chat_entry.id == "user123"
      assert chat_entry.start_time == 1_700_000_000
    end

    test "handles empty entries" do
      data = %{}

      result = GetMute.transform_response(data)

      assert result.chat_entries == []
      assert result.group_chat_entries == []
    end
  end

  describe "transform_entry/1" do
    test "transforms entry with string keys" do
      entry = %{
        "id" => "test123",
        "duration" => 1000,
        "startTime" => 12345,
        "systemTime" => 12346,
        "currentTime" => 12347,
        "muteMode" => 0
      }

      result = GetMute.transform_entry(entry)

      assert result.id == "test123"
      assert result.duration == 1000
      assert result.start_time == 12345
      assert result.system_time == 12346
      assert result.current_time == 12347
      assert result.mute_mode == 0
    end

    test "transforms entry with atom keys" do
      entry = %{
        id: "test456",
        duration: 2000,
        startTime: 22345,
        systemTime: 22346,
        currentTime: 22347,
        muteMode: 1
      }

      result = GetMute.transform_entry(entry)

      assert result.id == "test456"
      assert result.duration == 2000
      assert result.start_time == 22345
      assert result.system_time == 22346
      assert result.current_time == 22347
      assert result.mute_mode == 1
    end
  end

  describe "call/2" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetMute.call(session_no_service, credentials)
      end
    end
  end
end
