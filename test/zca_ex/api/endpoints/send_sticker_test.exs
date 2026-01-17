defmodule ZcaEx.Api.Endpoints.SendStickerTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZcaEx.Api.Endpoints.SendSticker
  alias ZcaEx.HTTP.{AccountClientMock, Response}
  alias ZcaEx.Test.Fixtures

  setup :verify_on_exit!

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/5 validation" do
    test "returns error for nil sticker", %{session: session, credentials: credentials} do
      result = SendSticker.call(nil, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Sticker is required"
    end

    test "returns error for empty thread_id", %{session: session, credentials: credentials} do
      sticker = %{id: 1, cate_id: 0, type: 1}
      result = SendSticker.call(sticker, "", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Missing threadId"
    end

    test "returns error for nil thread_id", %{session: session, credentials: credentials} do
      sticker = %{id: 1, cate_id: 0, type: 1}
      result = SendSticker.call(sticker, nil, :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Missing threadId"
    end

    test "returns error for missing sticker id", %{session: session, credentials: credentials} do
      sticker = %{cate_id: 0, type: 1}
      result = SendSticker.call(sticker, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "id"
    end

    test "returns error for missing sticker cate_id", %{session: session, credentials: credentials} do
      sticker = %{id: 1, type: 1}
      result = SendSticker.call(sticker, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "cateId"
    end

    test "returns error for missing sticker type", %{session: session, credentials: credentials} do
      sticker = %{id: 1, cate_id: 0}
      result = SendSticker.call(sticker, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "type"
    end

    test "accepts cate_id of 0", %{session: session, credentials: credentials} do
      response_data = %{"msgId" => 12345}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      sticker = %{id: 1, cate_id: 0, type: 1}
      result = SendSticker.call(sticker, "user123", :user, session, credentials)

      assert {:ok, %{msg_id: 12345}} = result
    end
  end

  describe "call/5 to user" do
    test "sends sticker to user", %{session: session, credentials: credentials} do
      response_data = %{"msgId" => 12345}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, body, _user_agent, _headers ->
        assert url =~ "/api/message/sticker"
        assert url =~ "nretry=0"
        assert body =~ "params="
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      sticker = %{id: 100, cate_id: 10, type: 2}
      result = SendSticker.call(sticker, "user123", :user, session, credentials)

      assert {:ok, %{msg_id: 12345}} = result
    end

    test "includes correct params for user sticker", %{session: session, credentials: credentials} do
      response_data = %{"msgId" => 12345}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "chat.zalo.me"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      sticker = %{id: 100, cate_id: 10, type: 2}
      _result = SendSticker.call(sticker, "user123", :user, session, credentials)
    end
  end

  describe "call/5 to group" do
    test "sends sticker to group", %{session: session, credentials: credentials} do
      response_data = %{"msgId" => 67890}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/group/sticker"
        assert url =~ "nretry=0"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      sticker = %{id: 200, cate_id: 20, type: 3}
      result = SendSticker.call(sticker, "group456", :group, session, credentials)

      assert {:ok, %{msg_id: 67890}} = result
    end

    test "uses group service URL", %{session: session, credentials: credentials} do
      response_data = %{"msgId" => 67890}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "groupchat.zalo.me"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      sticker = %{id: 200, cate_id: 20, type: 3}
      _result = SendSticker.call(sticker, "group456", :group, session, credentials)
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      response = Fixtures.build_error_response(-1, "Rate limited")

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      sticker = %{id: 100, cate_id: 10, type: 2}
      result = SendSticker.call(sticker, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Rate limited"
    end
  end
end
