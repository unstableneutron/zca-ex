defmodule ZcaEx.Api.Endpoints.SendVideoTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SendVideo
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
      url = SendVideo.build_url(session, :user)

      assert url =~ "https://file.zalo.me/api/message/forward"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds group forward URL", %{session: session} do
      url = SendVideo.build_url(session, :group)

      assert url =~ "https://file.zalo.me/api/group/forward"
    end
  end

  describe "get_base_url/2" do
    test "returns file URL with /api/message/forward for user", %{session: session} do
      url = SendVideo.get_base_url(session, :user)
      assert url == "https://file.zalo.me/api/message/forward"
    end

    test "returns file URL with /api/group/forward for group", %{session: session} do
      url = SendVideo.get_base_url(session, :group)
      assert url == "https://file.zalo.me/api/group/forward"
    end
  end

  describe "build_params/5" do
    test "builds params for user video message", %{credentials: creds} do
      options = %{
        video_url: "https://example.com/video.mp4",
        thumbnail_url: "https://example.com/thumb.jpg",
        msg: "Check this out!"
      }

      params = SendVideo.build_params(options, "user123", :user, 1024, creds)

      assert params.toId == "user123"
      assert params.imei == creds.imei
      assert params.ttl == 0
      assert params.zsource == 704
      assert params.msgType == 5
      refute Map.has_key?(params, :grid)
      refute Map.has_key?(params, :visibility)

      msg_info = Jason.decode!(params.msgInfo)
      assert msg_info["videoUrl"] == "https://example.com/video.mp4"
      assert msg_info["thumbUrl"] == "https://example.com/thumb.jpg"
      assert msg_info["fileSize"] == 1024
      assert msg_info["title"] == "Check this out!"
      assert msg_info["width"] == 1280
      assert msg_info["height"] == 720
      assert msg_info["duration"] == 0
    end

    test "builds params for group video message", %{credentials: creds} do
      options = %{
        video_url: "https://example.com/video.mp4",
        thumbnail_url: "https://example.com/thumb.jpg"
      }

      params = SendVideo.build_params(options, "group123", :group, 2048, creds)

      assert params.grid == "group123"
      assert params.visibility == 0
      assert params.imei == creds.imei
      refute Map.has_key?(params, :toId)
    end

    test "includes custom dimensions and duration", %{credentials: creds} do
      options = %{
        video_url: "https://example.com/video.mp4",
        thumbnail_url: "https://example.com/thumb.jpg",
        width: 1920,
        height: 1080,
        duration: 5500
      }

      params = SendVideo.build_params(options, "user123", :user, 1024, creds)

      msg_info = Jason.decode!(params.msgInfo)
      assert msg_info["width"] == 1920
      assert msg_info["height"] == 1080
      assert msg_info["duration"] == 5500
    end

    test "includes custom ttl", %{credentials: creds} do
      options = %{
        video_url: "https://example.com/video.mp4",
        thumbnail_url: "https://example.com/thumb.jpg",
        ttl: 60000
      }

      params = SendVideo.build_params(options, "user123", :user, 1024, creds)

      assert params.ttl == 60000
    end

    test "msgInfo contains correct properties structure", %{credentials: creds} do
      options = %{
        video_url: "https://example.com/video.mp4",
        thumbnail_url: "https://example.com/thumb.jpg"
      }

      params = SendVideo.build_params(options, "user123", :user, 1024, creds)

      msg_info = Jason.decode!(params.msgInfo)
      props = msg_info["properties"]

      assert props["color"] == -1
      assert props["size"] == -1
      assert props["type"] == 1003
      assert props["subType"] == 0
      assert props["ext"]["sSrcType"] == -1
      assert props["ext"]["sSrcStr"] == ""
      assert props["ext"]["msg_warning_type"] == 0
    end
  end
end
