defmodule ZcaEx.Api.Endpoints.SetArchivedConversationsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SetArchivedConversations
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "label" => ["https://label.zalo.me"]
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

  describe "normalize_conversations/1" do
    test "returns list as-is" do
      conversations = [%{id: "123", type: :user}]
      assert SetArchivedConversations.normalize_conversations(conversations) == conversations
    end

    test "wraps single map in list" do
      conversation = %{id: "123", type: :user}
      assert SetArchivedConversations.normalize_conversations(conversation) == [conversation]
    end
  end

  describe "validate_conversations/1" do
    test "returns :ok for valid conversations" do
      conversations = [
        %{id: "user123", type: :user},
        %{id: "group456", type: :group}
      ]

      assert :ok == SetArchivedConversations.validate_conversations(conversations)
    end

    test "returns error for empty list" do
      assert {:error, %ZcaEx.Error{message: "conversations cannot be empty"}} =
               SetArchivedConversations.validate_conversations([])
    end

    test "returns error for invalid conversation" do
      assert {:error, %ZcaEx.Error{}} =
               SetArchivedConversations.validate_conversations([%{id: "", type: :user}])
    end

    test "returns error for missing type" do
      assert {:error, %ZcaEx.Error{}} =
               SetArchivedConversations.validate_conversations([%{id: "123"}])
    end

    test "returns error for invalid type" do
      assert {:error, %ZcaEx.Error{}} =
               SetArchivedConversations.validate_conversations([%{id: "123", type: :invalid}])
    end
  end

  describe "build_params/3" do
    test "builds correct params for archive (is_archived=true)" do
      conversations = [%{id: "user123", type: :user}]
      params = SetArchivedConversations.build_params(true, conversations, "test-imei")

      assert params.actionType == 0
      assert params.imei == "test-imei"
      assert params.ids == [%{id: "user123", type: 0}]
      assert is_integer(params.version)
    end

    test "builds correct params for unarchive (is_archived=false)" do
      conversations = [%{id: "group456", type: :group}]
      params = SetArchivedConversations.build_params(false, conversations, "test-imei")

      assert params.actionType == 1
      assert params.ids == [%{id: "group456", type: 1}]
    end

    test "converts thread type correctly" do
      conversations = [
        %{id: "user1", type: :user},
        %{id: "group1", type: :group}
      ]

      params = SetArchivedConversations.build_params(true, conversations, "imei")

      assert Enum.at(params.ids, 0) == %{id: "user1", type: 0}
      assert Enum.at(params.ids, 1) == %{id: "group1", type: 1}
    end

    test "version is a timestamp" do
      conversations = [%{id: "123", type: :user}]
      before = :os.system_time(:millisecond)
      params = SetArchivedConversations.build_params(true, conversations, "imei")
      after_time = :os.system_time(:millisecond)

      assert params.version >= before
      assert params.version <= after_time
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = SetArchivedConversations.build_base_url(session)

      assert url =~ "https://label.zalo.me/api/archivedchat/update"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = SetArchivedConversations.build_url(session, encrypted)

      assert url =~ "https://label.zalo.me/api/archivedchat/update"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with boolean needResync" do
      data = %{"needResync" => true, "version" => 123_456}
      result = SetArchivedConversations.transform_response(data)

      assert result.need_resync == true
      assert result.version == 123_456
    end

    test "transforms response with integer needResync" do
      data = %{"needResync" => 1, "version" => 123_456}
      result = SetArchivedConversations.transform_response(data)

      assert result.need_resync == true
    end

    test "handles false needResync" do
      data = %{"needResync" => false, "version" => 0}
      result = SetArchivedConversations.transform_response(data)

      assert result.need_resync == false
    end

    test "handles missing fields" do
      data = %{}
      result = SetArchivedConversations.transform_response(data)

      assert result.need_resync == false
      assert result.version == 0
    end
  end

  describe "call/4 validation" do
    test "returns error when conversations is empty", %{
      session: session,
      credentials: credentials
    } do
      assert {:error, %ZcaEx.Error{message: "conversations cannot be empty"}} =
               SetArchivedConversations.call(session, credentials, true, [])
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        SetArchivedConversations.call(session_no_service, credentials, true, %{
          id: "123",
          type: :user
        })
      end
    end
  end
end
