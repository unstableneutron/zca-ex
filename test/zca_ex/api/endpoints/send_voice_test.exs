defmodule ZcaEx.Api.Endpoints.SendVoiceTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SendVoice
  alias ZcaEx.Account.Session
  alias ZcaEx.Account.Credentials

  setup do
    session = %Session{
      uid: "123456789",
      secret_key: Base.encode64(:crypto.strong_rand_bytes(32)),
      zpw_service_map: %{
        "chat" => ["https://chat.zalo.me"],
        "group" => ["https://group.zalo.me"],
        "file" => ["https://file.zalo.me"]
      },
      api_type: 30,
      api_version: 645
    }

    {:ok, credentials} =
      Credentials.new(
        imei: "test-imei-123456",
        user_agent: "Mozilla/5.0 Test",
        cookies: [%{"name" => "test", "value" => "cookie"}]
      )

    {:ok, session: session, credentials: credentials}
  end

  describe "build_url/2" do
    test "builds user forward URL", %{session: session} do
      url = SendVoice.build_url(session, :user)

      assert url =~ "https://file.zalo.me/api/message/forward"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds group forward URL", %{session: session} do
      url = SendVoice.build_url(session, :group)

      assert url =~ "https://file.zalo.me/api/group/forward"
    end
  end

  describe "get_base_url/2" do
    test "returns file URL with /api/message/forward for user", %{session: session} do
      url = SendVoice.get_base_url(session, :user)
      assert url == "https://file.zalo.me/api/message/forward"
    end

    test "returns file URL with /api/group/forward for group", %{session: session} do
      url = SendVoice.get_base_url(session, :group)
      assert url == "https://file.zalo.me/api/group/forward"
    end
  end

  describe "build_params/5" do
    test "builds params for user voice message", %{credentials: creds} do
      options = %{voice_url: "https://example.com/voice.m4a"}

      params = SendVoice.build_params(options, "user123", :user, 512, creds)

      assert params.toId == "user123"
      assert params.imei == creds.imei
      assert params.ttl == 0
      assert params.zsource == -1
      assert params.msgType == 3
      refute Map.has_key?(params, :grid)
      refute Map.has_key?(params, :visibility)

      msg_info = Jason.decode!(params.msgInfo)
      assert msg_info["voiceUrl"] == "https://example.com/voice.m4a"
      assert msg_info["m4aUrl"] == "https://example.com/voice.m4a"
      assert msg_info["fileSize"] == 512
    end

    test "builds params for group voice message", %{credentials: creds} do
      options = %{voice_url: "https://example.com/voice.m4a"}

      params = SendVoice.build_params(options, "group123", :group, 1024, creds)

      assert params.grid == "group123"
      assert params.visibility == 0
      assert params.imei == creds.imei
      refute Map.has_key?(params, :toId)
    end

    test "includes custom ttl", %{credentials: creds} do
      options = %{voice_url: "https://example.com/voice.m4a", ttl: 30000}

      params = SendVoice.build_params(options, "user123", :user, 512, creds)

      assert params.ttl == 30000
    end

    test "clientId is a string timestamp", %{credentials: creds} do
      options = %{voice_url: "https://example.com/voice.m4a"}

      params = SendVoice.build_params(options, "user123", :user, 512, creds)

      assert is_binary(params.clientId)
      {parsed, ""} = Integer.parse(params.clientId)
      assert parsed > 0
    end
  end
end
