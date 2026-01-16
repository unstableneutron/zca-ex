defmodule ZcaEx.Api.Endpoints.UpdateAutoReplyTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateAutoReply
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

  describe "build_params/8" do
    test "builds correct params for scope 0", %{credentials: credentials} do
      params = UpdateAutoReply.build_params(123, "Hello!", true, 1000, 2000, 0, nil, credentials)

      assert params.cliLang == "vi"
      assert params.id == 123
      assert params.enable == true
      assert params.content == "Hello!"
      assert params.startTime == 1000
      assert params.endTime == 2000
      assert params.recurrence == ["RRULE:FREQ=DAILY;"]
      assert params.scope == 0
      assert params.uids == []
    end

    test "builds correct params for scope 2 with uids", %{credentials: credentials} do
      params = UpdateAutoReply.build_params(1, "Reply", true, 0, 100, 2, ["uid1", "uid2"], credentials)

      assert params.id == 1
      assert params.scope == 2
      assert params.uids == ["uid1", "uid2"]
    end

    test "builds correct params for scope 3 with single uid", %{credentials: credentials} do
      params = UpdateAutoReply.build_params(1, "Reply", true, 0, 100, 3, "uid1", credentials)

      assert params.scope == 3
      assert params.uids == ["uid1"]
    end
  end

  describe "build_url/2" do
    test "builds correct URL", %{session: session} do
      url = UpdateAutoReply.build_url("https://autoreply.zalo.me", session)

      assert url =~ "https://autoreply.zalo.me/api/autoreply/update"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      url = UpdateAutoReply.build_url("https://autoreply2.zalo.me", session)

      assert url =~ "https://autoreply2.zalo.me/api/autoreply/update"
    end
  end

  describe "update/9 validation" do
    test "returns error for zero id", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update(0, "Hi", true, 0, 100, 0, nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "id must be a positive integer"
      assert error.code == :invalid_input
    end

    test "returns error for negative id", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update(-1, "Hi", true, 0, 100, 0, nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "id must be a positive integer"
    end

    test "returns error for non-integer id", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update("123", "Hi", true, 0, 100, 0, nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "id must be a positive integer"
    end

    test "returns error for empty content", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update(1, "", true, 0, 100, 0, nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "content must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil content", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update(1, nil, true, 0, 100, 0, nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "content must be a non-empty string"
    end

    test "returns error for non-boolean enabled?", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update(1, "Hi", "yes", 0, 100, 0, nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "enabled? must be a boolean"
      assert error.code == :invalid_input
    end

    test "returns error for negative start_time", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update(1, "Hi", true, -1, 100, 0, nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "start_time must be a non-negative integer"
      assert error.code == :invalid_input
    end

    test "returns error for end_time <= start_time", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update(1, "Hi", true, 100, 100, 0, nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "end_time must be greater than start_time"
      assert error.code == :invalid_input
    end

    test "returns error for invalid scope", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update(1, "Hi", true, 0, 100, 5, nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "scope must be 0, 1, 2, or 3"
      assert error.code == :invalid_input
    end

    test "returns error for scope 2 without uids", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update(1, "Hi", true, 0, 100, 2, nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "uids required for scope 2 or 3"
      assert error.code == :invalid_input
    end

    test "returns error for scope 3 without uids", %{session: session, credentials: credentials} do
      result = UpdateAutoReply.update(1, "Hi", true, 0, 100, 3, [], session, credentials)

      assert {:error, error} = result
      assert error.message == "uids required for scope 2 or 3"
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = UpdateAutoReply.update(1, "Hi", true, 0, 100, 0, nil, session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "auto_reply service URL not found"
      assert error.code == :service_not_found
    end
  end
end
