defmodule ZcaEx.Api.Endpoints.GetArchivedChatListTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetArchivedChatList
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "label" => ["https://label.zalo.me"]
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

  describe "build_params/1" do
    test "builds params with version and imei", %{credentials: credentials} do
      params = GetArchivedChatList.build_params(credentials)

      assert params.version == 1
      assert params.imei == "test-imei-12345"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetArchivedChatList.build_base_url(session)

      assert url == "https://label.zalo.me/api/archivedchat/list"
    end

    test "uses label service", %{session: session} do
      url = GetArchivedChatList.build_base_url(session)

      assert url =~ "label.zalo.me"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params and session params", %{session: session} do
      encrypted_params = "encrypted_test_params"
      url = GetArchivedChatList.build_url(session, encrypted_params)

      assert url =~ "https://label.zalo.me/api/archivedchat/list"
      assert url =~ "params=encrypted_test_params"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{"items" => [%{"id" => "1"}, %{"id" => "2"}], "version" => 5}
      result = GetArchivedChatList.transform_response(data)

      assert result.items == [%{"id" => "1"}, %{"id" => "2"}]
      assert result.version == 5
    end

    test "transforms response with atom keys" do
      data = %{items: [%{id: "1"}], version: 3}
      result = GetArchivedChatList.transform_response(data)

      assert result.items == [%{id: "1"}]
      assert result.version == 3
    end

    test "handles missing fields with defaults" do
      data = %{}
      result = GetArchivedChatList.transform_response(data)

      assert result.items == []
      assert result.version == 0
    end
  end

  describe "call/2 service URL handling" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetArchivedChatList.call(session_no_service, credentials)
      end
    end

    test "raises when label service missing", %{session: session, credentials: credentials} do
      session_wrong_service = %{
        session
        | zpw_service_map: %{"other" => ["https://other.zalo.me"]}
      }

      assert_raise RuntimeError, ~r/Service URL not found for label/, fn ->
        GetArchivedChatList.call(session_wrong_service, credentials)
      end
    end
  end
end
