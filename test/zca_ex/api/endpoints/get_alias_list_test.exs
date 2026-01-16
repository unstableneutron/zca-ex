defmodule ZcaEx.Api.Endpoints.GetAliasListTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetAliasList
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "alias" => ["https://alias.zalo.me"]
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

  describe "build_params/3" do
    test "builds params with page, count, and imei" do
      params = GetAliasList.build_params(2, 50, "test-imei-123")

      assert params == %{page: 2, count: 50, imei: "test-imei-123"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      {:ok, url} = GetAliasList.build_base_url(session)

      assert url =~ "https://alias.zalo.me/api/alias/list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"alias" => "https://alias2.zalo.me"}}
      {:ok, url} = GetAliasList.build_base_url(session)

      assert url =~ "https://alias2.zalo.me/api/alias/list"
    end

    test "returns error when service URL not found", %{session: session} do
      session = %{session | zpw_service_map: %{}}

      assert {:error, %ZcaEx.Error{message: "alias service URL not found"}} =
               GetAliasList.build_base_url(session)
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params in query", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetAliasList.build_url("https://alias.zalo.me", encrypted, session)

      assert url =~ "https://alias.zalo.me/api/alias/list"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms items with userId and alias" do
      data = %{
        "items" => [
          %{"userId" => "user1", "alias" => "Friend 1"},
          %{"userId" => "user2", "alias" => "Friend 2"}
        ],
        "updateTime" => 1_234_567_890
      }

      result = GetAliasList.transform_response(data)

      assert result.items == [
               %{user_id: "user1", alias: "Friend 1"},
               %{user_id: "user2", alias: "Friend 2"}
             ]

      assert result.update_time == 1_234_567_890
    end

    test "handles empty items list" do
      data = %{"items" => [], "updateTime" => 1_000_000}

      result = GetAliasList.transform_response(data)

      assert result.items == []
      assert result.update_time == 1_000_000
    end

    test "handles missing items" do
      data = %{"updateTime" => 1_000_000}

      result = GetAliasList.transform_response(data)

      assert result.items == []
    end

    test "handles atom keys in response" do
      data = %{
        items: [%{userId: "user1", alias: "Alias 1"}],
        updateTime: 1_111_111
      }

      result = GetAliasList.transform_response(data)

      assert result.items == [%{user_id: "user1", alias: "Alias 1"}]
      assert result.update_time == 1_111_111
    end

    test "handles snake_case keys in response" do
      data = %{
        "items" => [%{"user_id" => "user1", "alias" => "Alias 1"}],
        "update_time" => 1_111_111
      }

      result = GetAliasList.transform_response(data)

      assert result.items == [%{user_id: "user1", alias: "Alias 1"}]
      assert result.update_time == 1_111_111
    end
  end

  describe "list/4 validation" do
    test "returns error when page is not a positive integer", %{
      session: session,
      credentials: credentials
    } do
      assert {:error, %ZcaEx.Error{message: "page must be a positive integer"}} =
               GetAliasList.list(0, 100, session, credentials)

      assert {:error, %ZcaEx.Error{message: "page must be a positive integer"}} =
               GetAliasList.list(-1, 100, session, credentials)
    end

    test "returns error when count is not a positive integer", %{
      session: session,
      credentials: credentials
    } do
      assert {:error, %ZcaEx.Error{message: "count must be a positive integer"}} =
               GetAliasList.list(1, 0, session, credentials)

      assert {:error, %ZcaEx.Error{message: "count must be a positive integer"}} =
               GetAliasList.list(1, -1, session, credentials)
    end

    test "returns error when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert {:error, %ZcaEx.Error{message: "alias service URL not found"}} =
               GetAliasList.list(1, 100, session_no_service, credentials)
    end
  end
end
