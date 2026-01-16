defmodule ZcaEx.Api.Endpoints.GetFriendBoardListTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetFriendBoardList
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "friend_board" => ["https://friendboard.zalo.me"]
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

  describe "build_params/2" do
    test "builds correct params" do
      params = GetFriendBoardList.build_params("conv123", "test-imei")

      assert params == %{
               conversationId: "conv123",
               version: 0,
               imei: "test-imei"
             }
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetFriendBoardList.build_url("https://friendboard.zalo.me", session, encrypted)

      assert url =~ "https://friendboard.zalo.me/api/friendboard/list"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      {:ok, url} = GetFriendBoardList.build_base_url(session)

      assert url =~ "https://friendboard.zalo.me/api/friendboard/list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"friend_board" => "https://fb2.zalo.me"}}
      {:ok, url} = GetFriendBoardList.build_base_url(session)

      assert url =~ "https://fb2.zalo.me/api/friendboard/list"
    end

    test "returns error when service URL not found", %{session: session} do
      session = %{session | zpw_service_map: %{}}

      assert {:error, error} = GetFriendBoardList.build_base_url(session)
      assert error.message =~ "friend_board service URL not found"
      assert error.code == :service_not_found
    end
  end

  describe "get/3 validation" do
    test "returns error for empty conversation_id", %{session: session, credentials: credentials} do
      result = GetFriendBoardList.get("", session, credentials)

      assert {:error, error} = result
      assert error.message == "conversation_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil conversation_id", %{session: session, credentials: credentials} do
      result = GetFriendBoardList.get(nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "conversation_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for non-string conversation_id", %{
      session: session,
      credentials: credentials
    } do
      result = GetFriendBoardList.get(123, session, credentials)

      assert {:error, error} = result
      assert error.message == "conversation_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = GetFriendBoardList.get("conv123", session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "friend_board service URL not found"
      assert error.code == :service_not_found
    end
  end

  describe "transform_response/1" do
    test "transforms response with data and version" do
      data = %{
        "data" => [%{"id" => "1", "name" => "Item 1"}, %{"id" => "2", "name" => "Item 2"}],
        "version" => 5
      }

      result = GetFriendBoardList.transform_response(data)

      assert result.data == [%{"id" => "1", "name" => "Item 1"}, %{"id" => "2", "name" => "Item 2"}]
      assert result.version == 5
    end

    test "handles atom keys" do
      data = %{
        data: [%{"id" => "1"}],
        version: 3
      }

      result = GetFriendBoardList.transform_response(data)

      assert result.data == [%{"id" => "1"}]
      assert result.version == 3
    end

    test "handles missing data field" do
      data = %{"version" => 2}

      result = GetFriendBoardList.transform_response(data)

      assert result.data == []
      assert result.version == 2
    end

    test "handles missing version field" do
      data = %{"data" => [%{"id" => "1"}]}

      result = GetFriendBoardList.transform_response(data)

      assert result.data == [%{"id" => "1"}]
      assert result.version == 0
    end

    test "handles empty response" do
      result = GetFriendBoardList.transform_response(%{})

      assert result.data == []
      assert result.version == 0
    end
  end
end
