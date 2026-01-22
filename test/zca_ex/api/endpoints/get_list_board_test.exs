defmodule ZcaEx.Api.Endpoints.GetListBoardTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetListBoard
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group_board" => ["https://groupboard.zalo.me"]
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

  describe "build_params/4" do
    test "builds correct params" do
      params = GetListBoard.build_params("group123", 1, 20, "test-imei")

      assert params.group_id == "group123"
      assert params.board_type == 0
      assert params.page == 1
      assert params.count == 20
      assert params.last_id == 0
      assert params.last_type == 0
      assert params.imei == "test-imei"
    end

    test "builds correct params with custom page and count" do
      params = GetListBoard.build_params("group123", 3, 50, "test-imei")

      assert params.group_id == "group123"
      assert params.page == 3
      assert params.count == 50
    end
  end

  describe "build_url/3" do
    test "builds correct URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetListBoard.build_url("https://groupboard.zalo.me", session, encrypted)

      assert url =~ "https://groupboard.zalo.me/api/board/list"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      assert {:ok, url} = GetListBoard.build_base_url(session)

      assert url =~ "https://groupboard.zalo.me/api/board/list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "returns error when service URL not found" do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert {:error, error} = GetListBoard.build_base_url(session_no_service)
      assert error.code == :service_not_found
      assert error.message =~ "group_board service URL not found"
    end
  end

  describe "transform_response/1" do
    test "transforms response with items and count" do
      data = %{
        "items" => [
          %{"board_type" => 1, "data" => %{"title" => "Test"}},
          %{"board_type" => 2, "data" => %{"content" => "Content"}}
        ],
        "count" => 2
      }

      result = GetListBoard.transform_response(data)

      assert result.count == 2
      assert length(result.items) == 2
      assert Enum.at(result.items, 0).board_type == 1
      assert Enum.at(result.items, 0).data["title"] == "Test"
    end

    test "handles empty items" do
      data = %{"items" => [], "count" => 0}
      result = GetListBoard.transform_response(data)

      assert result.count == 0
      assert result.items == []
    end

    test "handles missing fields with defaults" do
      data = %{}
      result = GetListBoard.transform_response(data)

      assert result.count == 0
      assert result.items == []
    end

    test "parses JSON string in data.params for non-poll board types" do
      data = %{
        "items" => [
          %{
            "boardType" => 2,
            "data" => %{
              "title" => "Board",
              "params" => ~s({"key": "value", "nested": {"a": 1}})
            }
          }
        ],
        "count" => 1
      }

      result = GetListBoard.transform_response(data)

      assert length(result.items) == 1
      item = Enum.at(result.items, 0)
      assert item.board_type == 2
      assert item.data[:params]["key"] == "value"
      assert item.data[:params]["nested"]["a"] == 1
    end

    test "does NOT parse JSON string in data.params for poll board type (1)" do
      data = %{
        "items" => [
          %{
            "boardType" => 1,
            "data" => %{
              "title" => "Poll Board",
              "params" => ~s({"key": "value"})
            }
          }
        ],
        "count" => 1
      }

      result = GetListBoard.transform_response(data)

      item = Enum.at(result.items, 0)
      assert item.board_type == 1
      assert item.data["params"] == ~s({"key": "value"})
    end

    test "preserves non-JSON string in data.params for non-poll types" do
      data = %{
        "items" => [
          %{
            "boardType" => 2,
            "data" => %{
              "title" => "Board",
              "params" => "invalid json"
            }
          }
        ],
        "count" => 1
      }

      result = GetListBoard.transform_response(data)

      item = Enum.at(result.items, 0)
      assert item.board_type == 2
      assert item.data["params"] == "invalid json"
    end

    test "handles atom keys" do
      data = %{
        items: [%{board_type: 1, data: %{title: "Test"}}],
        count: 1
      }

      result = GetListBoard.transform_response(data)

      assert result.count == 1
      assert Enum.at(result.items, 0).board_type == 1
    end
  end

  describe "call/4 input validation" do
    test "returns error when group_id is empty", %{session: session, credentials: credentials} do
      assert {:error, error} = GetListBoard.call("", session, credentials)
      assert error.code == :invalid_input
      assert error.message =~ "group_id must be a non-empty string"
    end

    test "returns error when group_id is nil", %{session: session, credentials: credentials} do
      assert {:error, error} = GetListBoard.call(nil, session, credentials)
      assert error.code == :invalid_input
      assert error.message =~ "group_id must be a non-empty string"
    end

    test "returns error when group_id is not a string", %{
      session: session,
      credentials: credentials
    } do
      assert {:error, error} = GetListBoard.call(123, session, credentials)
      assert error.code == :invalid_input
      assert error.message =~ "group_id must be a non-empty string"
    end

    test "returns error when service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert {:error, error} = GetListBoard.call("group123", session_no_service, credentials)
      assert error.code == :service_not_found
      assert error.message =~ "group_board service URL not found"
    end
  end

  describe "service URL handling" do
    test "handles service URL as list" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{"group_board" => ["https://primary.zalo.me", "https://backup.zalo.me"]},
        api_type: 30,
        api_version: 645
      }

      assert {:ok, url} = GetListBoard.build_base_url(session)
      assert url =~ "https://primary.zalo.me"
    end

    test "handles service URL as string" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{"group_board" => "https://single.zalo.me"},
        api_type: 30,
        api_version: 645
      }

      assert {:ok, url} = GetListBoard.build_base_url(session)
      assert url =~ "https://single.zalo.me"
    end
  end
end
