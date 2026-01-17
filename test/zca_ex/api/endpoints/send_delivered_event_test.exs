defmodule ZcaEx.Api.Endpoints.SendDeliveredEventTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZcaEx.Api.Endpoints.SendDeliveredEvent
  alias ZcaEx.HTTP.{AccountClientMock, Response}
  alias ZcaEx.Test.Fixtures

  setup :verify_on_exit!

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/5 validation" do
    test "returns error for nil messages", %{session: session, credentials: credentials} do
      result = SendDeliveredEvent.call(true, nil, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "missing"
    end

    test "returns error for empty messages list", %{session: session, credentials: credentials} do
      result = SendDeliveredEvent.call(true, [], :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "between 1 and 50"
    end

    test "returns error for too many messages", %{session: session, credentials: credentials} do
      messages =
        for i <- 1..51 do
          build_message(%{msg_id: "#{i}", id_to: "receiver1"})
        end

      result = SendDeliveredEvent.call(true, messages, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "between 1 and 50"
    end
  end

  describe "call/5 to user" do
    test "sends delivered event for single message with is_seen=true", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, body, _user_agent, _headers ->
        assert url =~ "/api/message/deliveredv2"
        assert body =~ "params="
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      message = build_message(%{
        msg_id: "1000",
        cli_msg_id: "2000",
        uid_from: "sender123",
        id_to: "receiver456"
      })

      result = SendDeliveredEvent.call(true, [message], :user, session, credentials)

      assert :ok = result
    end

    test "sends delivered event for single message with is_seen=false", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      message = build_message(%{
        msg_id: "1000",
        cli_msg_id: "2000",
        uid_from: "sender123",
        id_to: "receiver456"
      })

      result = SendDeliveredEvent.call(false, [message], :user, session, credentials)

      assert :ok = result
    end

    test "sends delivered event for multiple messages", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      messages = [
        build_message(%{msg_id: "1", cli_msg_id: "1", uid_from: "sender1", id_to: "receiver1"}),
        build_message(%{msg_id: "2", cli_msg_id: "2", uid_from: "sender1", id_to: "receiver1"})
      ]

      result = SendDeliveredEvent.call(true, messages, :user, session, credentials)

      assert :ok = result
    end

    test "wraps single message in list", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      message = build_message(%{msg_id: "1", id_to: "receiver1"})

      result = SendDeliveredEvent.call(true, message, :user, session, credentials)

      assert :ok = result
    end
  end

  describe "call/5 to group" do
    test "sends delivered event to group", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/group/deliveredv2"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      message = build_message(%{
        msg_id: "3000",
        cli_msg_id: "4000",
        uid_from: "sender789",
        id_to: "group123"
      })

      result = SendDeliveredEvent.call(true, [message], :group, session, credentials)

      assert :ok = result
    end
  end

  describe "thread validation" do
    test "returns error when group messages belong to different groups", %{session: session, credentials: credentials} do
      messages = [
        build_message(%{msg_id: "1", id_to: "group1"}),
        build_message(%{msg_id: "2", id_to: "group2"})
      ]

      result = SendDeliveredEvent.call(true, messages, :group, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "same idTo for Group thread"
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      response = Fixtures.build_error_response(-1, "Rate limited")

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      message = build_message(%{msg_id: "1", id_to: "receiver1"})

      result = SendDeliveredEvent.call(true, [message], :user, session, credentials)

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
