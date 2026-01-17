defmodule ZcaEx.Api.Endpoints.DeleteChatTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZcaEx.Api.Endpoints.DeleteChat
  alias ZcaEx.HTTP.{AccountClientMock, Response}
  alias ZcaEx.Test.Fixtures

  setup :verify_on_exit!

  setup do
    session =
      Fixtures.build_session()
      |> Map.put(:zpw_service_map, %{
        "chat" => ["https://chat.example.com"],
        "group" => ["https://group.example.com"]
      })

    credentials = Fixtures.build_credentials()

    last_message = %{
      owner_id: "user123",
      cli_msg_id: "1000",
      global_msg_id: "2000"
    }

    {:ok, session: session, credentials: credentials, last_message: last_message}
  end

  describe "validation" do
    test "returns error for empty thread_id", %{
      session: session,
      credentials: credentials,
      last_message: last_message
    } do
      result = DeleteChat.call(session, credentials, last_message, "", :user)

      assert {:error, error} = result
      assert error.message =~ "Invalid thread_id"
    end

    test "returns error for nil thread_id", %{
      session: session,
      credentials: credentials,
      last_message: last_message
    } do
      result = DeleteChat.call(session, credentials, last_message, nil, :user)

      assert {:error, error} = result
      assert error.message =~ "Invalid thread_id"
    end

    test "returns error for invalid last_message missing owner_id", %{
      session: session,
      credentials: credentials
    } do
      invalid_message = %{cli_msg_id: "1000", global_msg_id: "2000"}
      result = DeleteChat.call(session, credentials, invalid_message, "thread123", :user)

      assert {:error, error} = result
      assert error.message =~ "Invalid last_message"
    end

    test "returns error for invalid last_message missing cli_msg_id", %{
      session: session,
      credentials: credentials
    } do
      invalid_message = %{owner_id: "user123", global_msg_id: "2000"}
      result = DeleteChat.call(session, credentials, invalid_message, "thread123", :user)

      assert {:error, error} = result
      assert error.message =~ "Invalid last_message"
    end

    test "returns error for invalid last_message missing global_msg_id", %{
      session: session,
      credentials: credentials
    } do
      invalid_message = %{owner_id: "user123", cli_msg_id: "1000"}
      result = DeleteChat.call(session, credentials, invalid_message, "thread123", :user)

      assert {:error, error} = result
      assert error.message =~ "Invalid last_message"
    end
  end

  describe "build_params/4" do
    test "builds params for user thread", %{credentials: credentials, last_message: last_message} do
      params = DeleteChat.build_params(last_message, "user456", :user, credentials)

      assert params.toid == "user456"
      assert params.imei == credentials.imei
      assert params.onlyMe == 1
      assert params.conver.ownerId == "user123"
      assert params.conver.cliMsgId == "1000"
      assert params.conver.globalMsgId == "2000"
      assert is_integer(params.cliMsgId)
      refute Map.has_key?(params, :grid)
    end

    test "builds params for group thread", %{credentials: credentials, last_message: last_message} do
      params = DeleteChat.build_params(last_message, "group789", :group, credentials)

      assert params.grid == "group789"
      assert params.onlyMe == 1
      assert params.conver.ownerId == "user123"
      assert params.conver.cliMsgId == "1000"
      assert params.conver.globalMsgId == "2000"
      assert is_integer(params.cliMsgId)
      refute Map.has_key?(params, :toid)
      refute Map.has_key?(params, :imei)
    end
  end

  describe "build_url/2" do
    test "builds URL for user thread", %{session: session} do
      url = DeleteChat.build_url(:user, session)

      assert url =~ "https://chat.example.com/api/message/deleteconver"
    end

    test "builds URL for group thread", %{session: session} do
      url = DeleteChat.build_url(:group, session)

      assert url =~ "https://group.example.com/api/group/deleteconver"
    end

    test "raises when chat service not in session" do
      session = Fixtures.build_session() |> Map.put(:zpw_service_map, %{})

      assert_raise RuntimeError, ~r/Service URL not found for chat/, fn ->
        DeleteChat.build_url(:user, session)
      end
    end

    test "raises when group service not in session" do
      session = Fixtures.build_session() |> Map.put(:zpw_service_map, %{})

      assert_raise RuntimeError, ~r/Service URL not found for group/, fn ->
        DeleteChat.build_url(:group, session)
      end
    end
  end

  describe "call/5 with valid params" do
    test "deletes user chat successfully", %{
      session: session,
      credentials: credentials,
      last_message: last_message
    } do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, body, _user_agent, _headers ->
        assert url =~ "/api/message/deleteconver"
        assert body =~ "params="
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = DeleteChat.call(session, credentials, last_message, "user456", :user)

      assert {:ok, %{status: 1}} = result
    end

    test "deletes group chat successfully", %{
      session: session,
      credentials: credentials,
      last_message: last_message
    } do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/group/deleteconver"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = DeleteChat.call(session, credentials, last_message, "group789", :group)

      assert {:ok, %{status: 1}} = result
    end

    test "defaults to user thread type", %{
      session: session,
      credentials: credentials,
      last_message: last_message
    } do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/message/deleteconver"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = DeleteChat.call(session, credentials, last_message, "user456")

      assert {:ok, %{status: 1}} = result
    end
  end

  describe "error handling" do
    test "returns error on API error", %{
      session: session,
      credentials: credentials,
      last_message: last_message
    } do
      response = Fixtures.build_error_response(-1, "Conversation not found")

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = DeleteChat.call(session, credentials, last_message, "user456", :user)

      assert {:error, error} = result
      assert error.message == "Conversation not found"
    end
  end
end
