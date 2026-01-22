defmodule ZcaEx.Api.Endpoints.SendSeenEventTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZcaEx.Api.Endpoints.SendSeenEvent
  alias ZcaEx.HTTP.{AccountClientMock, Response}
  alias ZcaEx.Test.Fixtures

  setup :verify_on_exit!

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/4 validation" do
    test "returns error for nil messages", %{session: session, credentials: credentials} do
      result = SendSeenEvent.call(nil, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "missing"
    end

    test "returns error for empty messages list", %{session: session, credentials: credentials} do
      result = SendSeenEvent.call([], :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "between 1 and 50"
    end

    test "returns error for too many messages", %{session: session, credentials: credentials} do
      messages =
        for i <- 1..51 do
          build_message(%{msg_id: "#{i}", uid_from: "sender1"})
        end

      result = SendSeenEvent.call(messages, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "between 1 and 50"
    end
  end

  describe "call/4 to user" do
    test "sends seen event for single message", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, body, _user_agent, _headers ->
        assert url =~ "/api/message/seenv2"
        assert body =~ "params="
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      message =
        build_message(%{
          msg_id: "1000",
          cli_msg_id: "2000",
          uid_from: "sender123",
          id_to: "receiver456"
        })

      result = SendSeenEvent.call([message], :user, session, credentials)

      assert :ok = result
    end

    test "sends seen event for multiple messages", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      messages = [
        build_message(%{msg_id: "1", cli_msg_id: "1", uid_from: "sender1", id_to: "me"}),
        build_message(%{msg_id: "2", cli_msg_id: "2", uid_from: "sender1", id_to: "me"})
      ]

      result = SendSeenEvent.call(messages, :user, session, credentials)

      assert :ok = result
    end

    test "wraps single message in list", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      message = build_message(%{msg_id: "1", uid_from: "sender1"})

      result = SendSeenEvent.call(message, :user, session, credentials)

      assert :ok = result
    end
  end

  describe "call/4 to group" do
    test "sends seen event to group", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/group/seenv2"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      message =
        build_message(%{
          msg_id: "3000",
          cli_msg_id: "4000",
          uid_from: "sender789",
          id_to: "group123"
        })

      result = SendSeenEvent.call([message], :group, session, credentials)

      assert :ok = result
    end
  end

  describe "thread validation" do
    test "returns error when messages belong to different threads (user)", %{
      session: session,
      credentials: credentials
    } do
      messages = [
        build_message(%{msg_id: "1", uid_from: "sender1"}),
        build_message(%{msg_id: "2", uid_from: "sender2"})
      ]

      result = SendSeenEvent.call(messages, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "same thread"
    end

    test "returns error when messages belong to different threads (group)", %{
      session: session,
      credentials: credentials
    } do
      messages = [
        build_message(%{msg_id: "1", id_to: "group1"}),
        build_message(%{msg_id: "2", id_to: "group2"})
      ]

      result = SendSeenEvent.call(messages, :group, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "same thread"
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      response = Fixtures.build_error_response(-1, "Rate limited")

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      message = build_message(%{msg_id: "1", uid_from: "sender1"})

      result = SendSeenEvent.call([message], :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Rate limited"
    end
  end

  defp build_message(overrides) do
    defaults = %{
      msg_id: "default_msg_id",
      cli_msg_id: "default_cli_msg_id",
      uid_from: "default_uid_from",
      id_to: "default_id_to",
      msg_type: "1",
      st: 0,
      at: 0,
      cmd: 0,
      ts: "0"
    }

    Map.merge(defaults, overrides)
  end
end
