defmodule ZcaEx.Api.Endpoints.DeleteMessageTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZcaEx.Api.Endpoints.DeleteMessage
  alias ZcaEx.HTTP.{AccountClientMock, Response}
  alias ZcaEx.Test.Fixtures

  setup :verify_on_exit!

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/4 validation" do
    test "returns error when deleting own message for everyone", %{session: session, credentials: credentials} do
      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: session.uid
        },
        thread_id: "group123",
        type: :group
      }

      result = DeleteMessage.call(destination, false, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "Use undo API instead"
    end

    test "returns error when deleting for everyone in private chat", %{session: session, credentials: credentials} do
      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: "other_user"
        },
        thread_id: "user456",
        type: :user
      }

      result = DeleteMessage.call(destination, false, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "Cannot delete for everyone in private chat"
    end
  end

  describe "call/4 with valid params" do
    test "deletes message in group for everyone", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, body, _user_agent, _headers ->
        assert url =~ "/api/group/deletemsg"
        assert body =~ "params="
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: "other_user"
        },
        thread_id: "group123",
        type: :group
      }

      result = DeleteMessage.call(destination, false, session, credentials)

      assert {:ok, %{status: 1}} = result
    end

    test "deletes message for self only in user chat", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/message/delete"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: "other_user"
        },
        thread_id: "user456",
        type: :user
      }

      result = DeleteMessage.call(destination, true, session, credentials)

      assert {:ok, %{status: 1}} = result
    end

    test "deletes own message for self only", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: session.uid
        },
        thread_id: "user456",
        type: :user
      }

      result = DeleteMessage.call(destination, true, session, credentials)

      assert {:ok, %{status: 1}} = result
    end

    test "defaults type to :user when not provided", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/message/delete"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: "other_user"
        },
        thread_id: "user456",
        type: :user
      }

      result = DeleteMessage.call(destination, true, session, credentials)

      assert {:ok, %{status: 1}} = result
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      response = Fixtures.build_error_response(-1, "Message not found")

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: "other_user"
        },
        thread_id: "group123",
        type: :group
      }

      result = DeleteMessage.call(destination, false, session, credentials)

      assert {:error, error} = result
      assert error.message == "Message not found"
    end
  end
end
