defmodule ZcaEx.Api.Endpoints.SendTypingEventTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZcaEx.Api.Endpoints.SendTypingEvent
  alias ZcaEx.HTTP.{AccountClientMock, Response}
  alias ZcaEx.Test.Fixtures

  setup :verify_on_exit!

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/5 validation" do
    test "returns error for nil thread_id", %{session: session, credentials: credentials} do
      result = SendTypingEvent.call(nil, :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Missing thread_id"
    end

    test "returns error for empty thread_id", %{session: session, credentials: credentials} do
      result = SendTypingEvent.call("", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Missing thread_id"
    end
  end

  describe "call/5 to user" do
    test "sends typing event to user", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, body, _user_agent, _headers ->
        assert url =~ "/api/message/typing"
        assert body =~ "params="
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = SendTypingEvent.call("user123", :user, session, credentials)

      assert :ok = result
    end

    test "sends typing event with page dest_type", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = SendTypingEvent.call("page123", :user, session, credentials, dest_type: :page)

      assert :ok = result
    end
  end

  describe "call/5 to group" do
    test "sends typing event to group", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/group/typing"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = SendTypingEvent.call("group456", :group, session, credentials)

      assert :ok = result
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      response = Fixtures.build_error_response(-1, "Session expired")

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = SendTypingEvent.call("user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Session expired"
    end
  end
end
