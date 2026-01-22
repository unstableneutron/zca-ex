defmodule ZcaEx.Api.Endpoints.SendMessageTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SendMessage
  alias ZcaEx.Account.Session
  alias ZcaEx.Account.Credentials
  alias ZcaEx.Model.{Mention, TextStyle}

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

  describe "build_message_url/4" do
    test "builds user message URL with /sms path", %{session: session} do
      url = SendMessage.build_message_url(session, :user, false, false)

      assert url =~ "https://chat.zalo.me/api/message/sms"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds group message URL with /sendmsg path", %{session: session} do
      url = SendMessage.build_message_url(session, :group, false, false)

      assert url =~ "https://group.zalo.me/api/group/sendmsg"
    end

    test "builds group message URL with /mention path when has mentions", %{session: session} do
      url = SendMessage.build_message_url(session, :group, false, true)

      assert url =~ "https://group.zalo.me/api/group/mention"
    end

    test "builds user quote URL with /quote path", %{session: session} do
      url = SendMessage.build_message_url(session, :user, true, false)

      assert url =~ "https://chat.zalo.me/api/message/quote"
    end

    test "builds group quote URL with /quote path", %{session: session} do
      url = SendMessage.build_message_url(session, :group, true, false)

      assert url =~ "https://group.zalo.me/api/group/quote"
    end

    test "quote takes precedence over mentions", %{session: session} do
      url = SendMessage.build_message_url(session, :group, true, true)

      assert url =~ "/quote"
      refute url =~ "/mention"
    end
  end

  describe "get_path/3" do
    test "returns /quote for quoted messages regardless of thread type" do
      assert SendMessage.get_path(:user, true, false) == "/quote"
      assert SendMessage.get_path(:user, true, true) == "/quote"
      assert SendMessage.get_path(:group, true, false) == "/quote"
      assert SendMessage.get_path(:group, true, true) == "/quote"
    end

    test "returns /sms for user messages without quote" do
      assert SendMessage.get_path(:user, false, false) == "/sms"
      assert SendMessage.get_path(:user, false, true) == "/sms"
    end

    test "returns /mention for group messages with mentions" do
      assert SendMessage.get_path(:group, false, true) == "/mention"
    end

    test "returns /sendmsg for group messages without mentions" do
      assert SendMessage.get_path(:group, false, false) == "/sendmsg"
    end
  end

  describe "build_params/6" do
    @client_id 123_456_789

    test "builds text params for user message", %{credentials: creds} do
      content = %{msg: "Hello"}

      params = SendMessage.build_params(content, "user123", :user, [], creds, @client_id)

      assert params.message == "Hello"
      assert params.toid == "user123"
      assert params.imei == creds.imei
      assert params.ttl == 0
      refute Map.has_key?(params, :grid)
      refute Map.has_key?(params, :visibility)
    end

    test "builds text params for group message", %{credentials: creds} do
      content = %{msg: "Hello group"}

      params = SendMessage.build_params(content, "group123", :group, [], creds, @client_id)

      assert params.message == "Hello group"
      assert params.grid == "group123"
      assert params.visibility == 0
      refute Map.has_key?(params, :toid)
      refute Map.has_key?(params, :imei)
    end

    test "includes mentionInfo when mentions provided", %{credentials: creds} do
      content = %{msg: "Hello @user"}
      mentions = [%{pos: 6, uid: "456", len: 5, type: 0}]

      params = SendMessage.build_params(content, "group123", :group, mentions, creds, @client_id)

      assert params.mentionInfo
      decoded = Jason.decode!(params.mentionInfo)
      assert [%{"pos" => 6, "uid" => "456", "len" => 5, "type" => 0}] = decoded
    end

    test "builds quote params with qmsg fields", %{credentials: creds} do
      quote_data = %{
        uid_from: "sender123",
        msg_id: 12345,
        cli_msg_id: 67890,
        msg_type: "chat.text",
        ts: 1_700_000_000,
        ttl: 3600,
        content: "Original message"
      }

      content = %{msg: "Reply", quote: quote_data}

      params = SendMessage.build_params(content, "user123", :user, [], creds, @client_id)

      assert params.message == "Reply"
      assert params.qmsgOwner == "sender123"
      assert params.qmsgId == 12345
      assert params.qmsgCliId == 67890
      assert params.qmsgType == 0
      assert params.qmsgTs == 1_700_000_000
      assert params.qmsgTTL == 3600
      assert params.qmsg == "Original message"
    end

    test "includes textProperties when styles provided", %{credentials: creds} do
      bold_style = TextStyle.new(0, 5, :bold)
      content = %{msg: "Hello", styles: [bold_style]}

      params = SendMessage.build_params(content, "user123", :user, [], creds, @client_id)

      assert params.textProperties
      text_props = Jason.decode!(params.textProperties)
      assert text_props["ver"] == 0
      assert length(text_props["styles"]) == 1
      [style] = text_props["styles"]
      assert style["start"] == 0
      assert style["len"] == 5
      assert style["st"] == "b"
    end

    test "includes metaData when urgency is important", %{credentials: creds} do
      content = %{msg: "Urgent!", urgency: :important}

      params = SendMessage.build_params(content, "user123", :user, [], creds, @client_id)

      assert params.metaData == %{urgency: 1}
    end

    test "includes metaData when urgency is urgent", %{credentials: creds} do
      content = %{msg: "Very urgent!", urgency: :urgent}

      params = SendMessage.build_params(content, "user123", :user, [], creds, @client_id)

      assert params.metaData == %{urgency: 2}
    end

    test "does not include metaData when urgency is default", %{credentials: creds} do
      content = %{msg: "Normal", urgency: :default}

      params = SendMessage.build_params(content, "user123", :user, [], creds, @client_id)

      refute Map.has_key?(params, :metaData)
    end

    test "includes custom ttl when provided", %{credentials: creds} do
      content = %{msg: "Expiring", ttl: 60000}

      params = SendMessage.build_params(content, "user123", :user, [], creds, @client_id)

      assert params.ttl == 60000
    end
  end

  describe "handle_mentions/3" do
    test "returns empty list for nil mentions" do
      assert {:ok, []} = SendMessage.handle_mentions(nil, "Hello", :group)
    end

    test "returns empty list for empty mentions" do
      assert {:ok, []} = SendMessage.handle_mentions([], "Hello", :group)
    end

    test "returns empty list for user thread type (mentions only valid in groups)" do
      mentions = [%{uid: "123", pos: 0, len: 5}]
      assert {:ok, []} = SendMessage.handle_mentions(mentions, "Hello", :user)
    end

    test "transforms mentions with correct type field" do
      mentions = [%{uid: "123", pos: 0, len: 5}]
      {:ok, result} = SendMessage.handle_mentions(mentions, "Hello", :group)

      assert length(result) == 1
      [mention] = result
      assert mention.uid == "123"
      assert mention.pos == 0
      assert mention.len == 5
      assert mention.type == 0
    end

    test "sets type to 1 for @all mentions (uid -1)" do
      mentions = [%{uid: "-1", pos: 0, len: 4}]
      {:ok, result} = SendMessage.handle_mentions(mentions, "@all", :group)

      [mention] = result
      assert mention.type == 1
    end

    test "filters out invalid mentions" do
      mentions = [
        %{uid: "123", pos: 0, len: 5},
        %{uid: nil, pos: 5, len: 3},
        %{uid: "456", pos: -1, len: 3},
        %{uid: "789", pos: 6, len: 0}
      ]

      {:ok, result} = SendMessage.handle_mentions(mentions, "Hello @user", :group)

      assert length(result) == 1
      assert hd(result).uid == "123"
    end

    test "returns error when total mention len exceeds message length" do
      mentions = [
        %{uid: "123", pos: 0, len: 10},
        %{uid: "456", pos: 11, len: 10}
      ]

      {:error, error} = SendMessage.handle_mentions(mentions, "Short", :group)

      assert error.message =~ "total mention len exceeds message length"
    end

    test "handles Mention struct" do
      mention = Mention.new("123", 0, 5)
      {:ok, result} = SendMessage.handle_mentions([mention], "Hello", :group)

      assert length(result) == 1
      [m] = result
      assert m.uid == "123"
      assert m.pos == 0
      assert m.len == 5
    end

    test "handles @all Mention struct" do
      mention = Mention.new_all(0, 4)
      {:ok, result} = SendMessage.handle_mentions([mention], "@all", :group)

      [m] = result
      assert m.uid == "-1"
      assert m.type == 1
    end

    test "multiple valid mentions are summed correctly" do
      mentions = [
        %{uid: "123", pos: 0, len: 5},
        %{uid: "456", pos: 6, len: 4}
      ]

      {:ok, result} = SendMessage.handle_mentions(mentions, "Hello @bob", :group)
      assert length(result) == 2
    end

    test "exact length match is valid" do
      mentions = [%{uid: "123", pos: 0, len: 5}]
      {:ok, result} = SendMessage.handle_mentions(mentions, "Hello", :group)
      assert length(result) == 1
    end
  end

  describe "get_base_url/2" do
    test "returns chat URL for user thread", %{session: session} do
      url = SendMessage.get_base_url(session, :user)
      assert url == "https://chat.zalo.me/api/message"
    end

    test "returns group URL for group thread", %{session: session} do
      url = SendMessage.get_base_url(session, :group)
      assert url == "https://group.zalo.me/api/group"
    end
  end
end
