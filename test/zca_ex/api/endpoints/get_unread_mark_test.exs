defmodule ZcaEx.Api.Endpoints.GetUnreadMarkTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZcaEx.Api.Endpoints.GetUnreadMark
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

  describe "build_params/0" do
    test "returns empty map" do
      params = GetUnreadMark.build_params()
      assert params == %{}
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      url = GetUnreadMark.build_url(session, "encrypted_params_here")

      assert url =~ "https://conv.example.com/api/conv/getUnreadMark"
      assert url =~ "params=encrypted_params_here"
    end

    test "raises when conversation service not in session" do
      session = Fixtures.build_session() |> Map.put(:zpw_service_map, %{})

      assert_raise RuntimeError, ~r/conversation service URL not found/, fn ->
        GetUnreadMark.build_url(session, "params")
      end
    end

    test "handles string URL instead of list" do
      session =
        Fixtures.build_session()
        |> Map.put(:zpw_service_map, %{"conversation" => "https://single.example.com"})

      url = GetUnreadMark.build_url(session, "params")

      assert url =~ "https://single.example.com/api/conv/getUnreadMark"
    end
  end

  describe "transform_response" do
    test "handles data as map", %{session: session, credentials: credentials} do
      response_data = %{
        "convsGroup" => [%{"id" => "g1"}],
        "convsUser" => [%{"id" => "u1"}],
        "status" => 1
      }
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :get, fn _account_id, _url, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = GetUnreadMark.get(session, credentials)

      assert {:ok, %{convs_group: [%{"id" => "g1"}], convs_user: [%{"id" => "u1"}], status: 1}} = result
    end

    test "returns empty lists when data is missing", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :get, fn _account_id, _url, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = GetUnreadMark.get(session, credentials)

      assert {:ok, %{convs_group: [], convs_user: [], status: 1}} = result
    end
  end

  describe "get/2 with valid params" do
    test "gets unread marks successfully", %{session: session, credentials: credentials} do
      response_data = %{
        "convsGroup" => [%{"id" => "group1", "ts" => 1_000_000}],
        "convsUser" => [%{"id" => "user1", "ts" => 2_000_000}],
        "status" => 1
      }
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :get, fn _account_id, url, _user_agent, _headers ->
        assert url =~ "/api/conv/getUnreadMark"
        assert url =~ "params="
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = GetUnreadMark.get(session, credentials)

      assert {:ok,
              %{
                convs_group: [%{"id" => "group1", "ts" => 1_000_000}],
                convs_user: [%{"id" => "user1", "ts" => 2_000_000}],
                status: 1
              }} = result
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      response = Fixtures.build_error_response(-1, "Operation failed")

      expect(AccountClientMock, :get, fn _account_id, _url, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      result = GetUnreadMark.get(session, credentials)

      assert {:error, error} = result
      assert error.message == "Operation failed"
    end
  end
end
