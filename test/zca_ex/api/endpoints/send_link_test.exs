defmodule ZcaEx.Api.Endpoints.SendLinkTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SendLink
  alias ZcaEx.Account.Session
  alias ZcaEx.Account.Credentials

  setup do
    session = %Session{
      uid: "123456789",
      secret_key: Base.encode64(:crypto.strong_rand_bytes(32)),
      zpw_service_map: %{
        "file" => ["https://file.zalo.me"],
        "chat" => ["https://chat.zalo.me"],
        "group" => ["https://group.zalo.me"],
        "friend" => ["https://friend.zalo.me"]
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

    link_data = %{
      thumb: "https://example.com/thumb.jpg",
      title: "Example Title",
      desc: "Example description",
      src: "example.com",
      href: "https://example.com",
      media: %{"type" => 0}
    }

    {:ok, session: session, credentials: credentials, link_data: link_data}
  end

  describe "build_url/2" do
    test "builds user URL with chat service and link path", %{session: session} do
      url = SendLink.build_url(session, :user)

      assert url =~ "https://chat.zalo.me/api/message/link"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds group URL with group service and sendlink path", %{session: session} do
      url = SendLink.build_url(session, :group)

      assert url =~ "https://group.zalo.me/api/group/sendlink"
    end
  end

  describe "build_params/5" do
    test "builds user params with toId and mentionInfo", %{credentials: creds, link_data: link_data} do
      options = %{link: "https://example.com"}

      params = SendLink.build_params(options, link_data, "user123", :user, creds)

      assert params.msg == "https://example.com"
      assert params.toId == "user123"
      assert params.mentionInfo == ""
      assert params.href == link_data.href
      assert params.src == link_data.src
      assert params.title == link_data.title
      assert params.desc == link_data.desc
      assert params.thumb == link_data.thumb
      assert params.type == 2
      assert params.ttl == 0
      refute Map.has_key?(params, :grid)
    end

    test "builds group params with grid and imei", %{credentials: creds, link_data: link_data} do
      options = %{link: "https://example.com"}

      params = SendLink.build_params(options, link_data, "group123", :group, creds)

      assert params.msg == "https://example.com"
      assert params.grid == "group123"
      assert params.imei == creds.imei
      refute Map.has_key?(params, :toId)
      refute Map.has_key?(params, :mentionInfo)
    end

    test "uses msg if provided and contains link", %{credentials: creds, link_data: link_data} do
      options = %{link: "https://example.com", msg: "Check this out https://example.com"}

      params = SendLink.build_params(options, link_data, "user123", :user, creds)

      assert params.msg == "Check this out https://example.com"
    end

    test "appends link to msg if not already present", %{credentials: creds, link_data: link_data} do
      options = %{link: "https://example.com", msg: "Check this out"}

      params = SendLink.build_params(options, link_data, "user123", :user, creds)

      assert params.msg == "Check this out https://example.com"
    end

    test "includes custom ttl when provided", %{credentials: creds, link_data: link_data} do
      options = %{link: "https://example.com", ttl: 60000}

      params = SendLink.build_params(options, link_data, "user123", :user, creds)

      assert params.ttl == 60000
    end

    test "encodes media as JSON", %{credentials: creds, link_data: link_data} do
      options = %{link: "https://example.com"}

      params = SendLink.build_params(options, link_data, "user123", :user, creds)

      assert is_binary(params.media)
      assert Jason.decode!(params.media) == link_data.media
    end
  end

  describe "send/5 validation" do
    test "returns error for missing link", %{session: session, credentials: creds} do
      assert {:error, error} = SendLink.send(%{}, "user123", :user, session, creds)
      assert error.message == "Missing link"
    end

    test "returns error for empty link", %{session: session, credentials: creds} do
      assert {:error, error} = SendLink.send(%{link: ""}, "user123", :user, session, creds)
      assert error.message == "Missing link"
    end

    test "returns error for missing thread_id", %{session: session, credentials: creds} do
      assert {:error, error} = SendLink.send(%{link: "https://example.com"}, "", :user, session, creds)
      assert error.message == "Missing threadId"
    end
  end
end
