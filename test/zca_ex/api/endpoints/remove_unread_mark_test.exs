defmodule ZcaEx.Api.Endpoints.RemoveUnreadMarkTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZcaEx.Api.Endpoints.RemoveUnreadMark
  alias ZcaEx.HTTP.{AccountClientMock, Response}
  alias ZcaEx.Test.Fixtures

  setup :verify_on_exit!

  setup do
    session =
      Fixtures.build_session()
      |> Map.put(:zpw_service_map, %{
        "conversation" => ["https://conv.example.com"]
      })

    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "validation" do
    test "returns error for empty thread_id", %{session: session, credentials: credentials} do
      result = RemoveUnreadMark.remove("", :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "thread_id must be a non-empty string"
    end

    test "returns error for nil thread_id", %{session: session, credentials: credentials} do
      result = RemoveUnreadMark.remove(nil, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "thread_id must be a non-empty string"
    end

    test "returns error for invalid thread_type", %{session: session, credentials: credentials} do
      result = RemoveUnreadMark.remove("user123", :invalid, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "thread_type must be :user or :group"
    end
  end

  describe "build_params/3" do
    test "builds params for user thread" do
      timestamp = 1_700_000_000_000
      params = RemoveUnreadMark.build_params("user456", :user, timestamp)

      assert Map.has_key?(params, "param")
      {:ok, inner} = Jason.decode(params["param"])

      assert inner["convsUser"] == ["user456"]
      assert inner["convsGroup"] == []
      assert inner["convsUserData"] == [%{"id" => "user456", "ts" => 1_700_000_000_000}]
      assert inner["convsGroupData"] == []
    end

    test "builds params for group thread" do
      timestamp = 1_700_000_000_000
      params = RemoveUnreadMark.build_params("group789", :group, timestamp)

      assert Map.has_key?(params, "param")
      {:ok, inner} = Jason.decode(params["param"])

      assert inner["convsGroup"] == ["group789"]
      assert inner["convsUser"] == []
      assert inner["convsGroupData"] == [%{"id" => "group789", "ts" => 1_700_000_000_000}]
      assert inner["convsUserData"] == []
    end
  end

  describe "build_url/1" do
    test "builds URL for conversation service", %{session: session} do
      url = RemoveUnreadMark.build_url(session)

      assert url =~ "https://conv.example.com/api/conv/removeUnreadMark"
    end

    test "raises when conversation service not in session" do
      session = Fixtures.build_session() |> Map.put(:zpw_service_map, %{})

      assert_raise RuntimeError, ~r/conversation service URL not found/, fn ->
        RemoveUnreadMark.build_url(session)
      end
    end

    test "handles string URL instead of list" do
      session =
        Fixtures.build_session()
        |> Map.put(:zpw_service_map, %{"conversation" => "https://single.example.com"})

      url = RemoveUnreadMark.build_url(session)

      assert url =~ "https://single.example.com/api/conv/removeUnreadMark"
    end
  end

  describe "transform_response" do
    test "handles data as map", %{session: session, credentials: credentials} do
      response_data = %{"updateId" => 123, "status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = RemoveUnreadMark.remove("user123", :user, session, credentials)

      assert {:ok, %{update_id: 123, status: 1}} = result
    end
  end

  describe "remove/4 with valid params" do
    test "removes unread mark for user successfully", %{
      session: session,
      credentials: credentials
    } do
      response_data = %{"updateId" => 100, "status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, body, _user_agent, _headers ->
        assert url =~ "/api/conv/removeUnreadMark"
        assert body =~ "params="
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = RemoveUnreadMark.remove("user456", :user, session, credentials)

      assert {:ok, %{update_id: 100, status: 1}} = result
    end

    test "removes unread mark for group successfully", %{
      session: session,
      credentials: credentials
    } do
      response_data = %{"updateId" => 200, "status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = RemoveUnreadMark.remove("group789", :group, session, credentials)

      assert {:ok, %{update_id: 200, status: 1}} = result
    end

    test "defaults to user thread type", %{session: session, credentials: credentials} do
      response_data = %{"updateId" => 300, "status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = RemoveUnreadMark.remove("user456", :user, session, credentials)

      assert {:ok, %{update_id: 300, status: 1}} = result
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      response = Fixtures.build_error_response(-1, "Operation failed")

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = RemoveUnreadMark.remove("user456", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Operation failed"
    end
  end
end
