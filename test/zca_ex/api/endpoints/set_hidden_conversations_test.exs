defmodule ZcaEx.Api.Endpoints.SetHiddenConversationsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SetHiddenConversations
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "conversation" => ["https://conversation.zalo.me"]
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

  describe "format_threads/2" do
    test "formats user threads with is_group=0" do
      result = SetHiddenConversations.format_threads(["user1", "user2"], :user)

      assert result == [
               %{thread_id: "user1", is_group: 0},
               %{thread_id: "user2", is_group: 0}
             ]
    end

    test "formats group threads with is_group=1" do
      result = SetHiddenConversations.format_threads(["group1", "group2"], :group)

      assert result == [
               %{thread_id: "group1", is_group: 1},
               %{thread_id: "group2", is_group: 1}
             ]
    end

    test "handles single thread" do
      result = SetHiddenConversations.format_threads(["thread1"], :user)

      assert result == [%{thread_id: "thread1", is_group: 0}]
    end
  end

  describe "build_params/3" do
    test "builds params for hiding (hidden=true)" do
      threads = [%{thread_id: "thread1", is_group: 0}]
      assert {:ok, params} = SetHiddenConversations.build_params(threads, true, "test-imei")

      assert params.imei == "test-imei"
      assert params.del_threads == "[]"
      assert Jason.decode!(params.add_threads) == [%{"thread_id" => "thread1", "is_group" => 0}]
    end

    test "builds params for unhiding (hidden=false)" do
      threads = [%{thread_id: "thread1", is_group: 0}]
      assert {:ok, params} = SetHiddenConversations.build_params(threads, false, "test-imei")

      assert params.imei == "test-imei"
      assert params.add_threads == "[]"
      assert Jason.decode!(params.del_threads) == [%{"thread_id" => "thread1", "is_group" => 0}]
    end

    test "builds params with multiple threads" do
      threads = [
        %{thread_id: "thread1", is_group: 0},
        %{thread_id: "thread2", is_group: 1}
      ]

      assert {:ok, params} = SetHiddenConversations.build_params(threads, true, "test-imei")

      decoded = Jason.decode!(params.add_threads)
      assert length(decoded) == 2
      assert Enum.at(decoded, 0) == %{"thread_id" => "thread1", "is_group" => 0}
      assert Enum.at(decoded, 1) == %{"thread_id" => "thread2", "is_group" => 1}
    end
  end

  describe "build_url/1" do
    test "builds correct URL with session params", %{session: session} do
      url = SetHiddenConversations.build_url(session)

      assert url =~ "https://conversation.zalo.me/api/hiddenconvers/add-remove"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = SetHiddenConversations.build_base_url(session)

      assert url == "https://conversation.zalo.me/api/hiddenconvers/add-remove"
    end
  end

  describe "call/5 validation" do
    test "returns error for empty thread_ids list", %{session: session, credentials: credentials} do
      result = SetHiddenConversations.call(session, credentials, true, [], :user)

      assert {:error, error} = result
      assert error.message == "Thread IDs cannot be empty"
    end

    test "returns error for empty string thread_id", %{session: session, credentials: credentials} do
      result = SetHiddenConversations.call(session, credentials, true, "", :user)

      assert {:error, error} = result
      assert error.message == "Thread ID cannot be empty"
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        SetHiddenConversations.call(session_no_service, credentials, true, "thread1", :user)
      end
    end
  end

  describe "call/5 single thread_id normalization" do
    test "accepts single string thread_id", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        SetHiddenConversations.call(session_no_service, credentials, true, "single_thread", :user)
      end
    end
  end
end
