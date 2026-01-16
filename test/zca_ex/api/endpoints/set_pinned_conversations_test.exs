defmodule ZcaEx.Api.Endpoints.SetPinnedConversationsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SetPinnedConversations
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "conversation" => ["https://tt-convers-wpa.chat.zalo.me"]
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
    test "builds params with pinned=true (actionType=1)" do
      params = SetPinnedConversations.build_params(true, ["u123", "u456"])

      assert params.actionType == 1
      assert params.conversations == ["u123", "u456"]
    end

    test "builds params with pinned=false (actionType=2)" do
      params = SetPinnedConversations.build_params(false, ["g789"])

      assert params.actionType == 2
      assert params.conversations == ["g789"]
    end
  end

  describe "format_conversations/2" do
    test "formats user thread IDs with 'u' prefix" do
      result = SetPinnedConversations.format_conversations(["123", "456"], :user)

      assert result == ["u123", "u456"]
    end

    test "formats group thread IDs with 'g' prefix" do
      result = SetPinnedConversations.format_conversations(["789", "012"], :group)

      assert result == ["g789", "g012"]
    end

    test "handles single thread ID in list" do
      assert SetPinnedConversations.format_conversations(["123"], :user) == ["u123"]
      assert SetPinnedConversations.format_conversations(["456"], :group) == ["g456"]
    end
  end

  describe "normalize_thread_ids/1" do
    test "converts single string to list" do
      assert SetPinnedConversations.normalize_thread_ids("123") == ["123"]
    end

    test "keeps list as is" do
      thread_ids = ["123", "456"]
      assert SetPinnedConversations.normalize_thread_ids(thread_ids) == thread_ids
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = SetPinnedConversations.build_base_url(session)

      assert url =~ "https://tt-convers-wpa.chat.zalo.me/api/pinconvers/updatev2"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/1" do
    test "builds URL with session params", %{session: session} do
      url = SetPinnedConversations.build_url(session)

      assert url =~ "https://tt-convers-wpa.chat.zalo.me/api/pinconvers/updatev2"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/5 validation" do
    test "returns error for empty thread_ids list", %{session: session, credentials: credentials} do
      result = SetPinnedConversations.call(session, credentials, true, [])

      assert {:error, error} = result
      assert error.message == "thread_ids cannot be empty"
    end

    test "raises for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        SetPinnedConversations.call(session_no_service, credentials, true, "123")
      end
    end
  end
end
