defmodule ZcaEx.Api.Endpoints.UndoMessageTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZcaEx.Api.Endpoints.UndoMessage
  alias ZcaEx.HTTP.{AccountClientMock, Response}
  alias ZcaEx.Test.Fixtures

  setup :verify_on_exit!

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "module structure" do
    test "exports call/4 and call/5 functions" do
      Code.ensure_loaded!(UndoMessage)
      assert function_exported?(UndoMessage, :call, 4)
      assert function_exported?(UndoMessage, :call, 5)
    end

    test "has proper moduledoc" do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} = Code.fetch_docs(UndoMessage)
      assert doc =~ "Undo"
    end
  end

  describe "typespec" do
    test "defines undo_payload type" do
      {:ok, types} = Code.Typespec.fetch_types(UndoMessage)
      type_names = Enum.map(types, fn {_, {name, _, _}} -> name end)
      assert :undo_payload in type_names
    end
  end

  describe "call/5 with valid params" do
    test "undoes message in user thread", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, body, _user_agent, _headers ->
        assert url =~ "/api/message/undo"
        assert body =~ "params="
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      payload = %{msg_id: "12345", cli_msg_id: "67890"}
      result = UndoMessage.call(payload, "user123", :user, session, credentials)

      assert {:ok, %{status: 1}} = result
    end

    test "undoes message in group thread", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/group/undomsg"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      payload = %{msg_id: "12345", cli_msg_id: "67890"}
      result = UndoMessage.call(payload, "group123", :group, session, credentials)

      assert {:ok, %{status: 1}} = result
    end

    test "defaults to user thread type", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/message/undo"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      payload = %{msg_id: "12345", cli_msg_id: "67890"}
      result = UndoMessage.call(payload, "user123", session, credentials)

      assert {:ok, %{status: 1}} = result
    end

    test "accepts integer msg_id and cli_msg_id", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      payload = %{msg_id: 12345, cli_msg_id: 67890}
      result = UndoMessage.call(payload, "user123", :user, session, credentials)

      assert {:ok, %{status: 1}} = result
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      response = Fixtures.build_error_response(-1, "Message not found")

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      payload = %{msg_id: "12345", cli_msg_id: "67890"}
      result = UndoMessage.call(payload, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Message not found"
    end
  end
end
