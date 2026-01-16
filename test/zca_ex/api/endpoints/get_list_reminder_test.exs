defmodule ZcaEx.Api.Endpoints.GetListReminderTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetListReminder
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group_board" => ["https://board.zalo.me"]
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

  describe "get_path/1" do
    test "returns user path for :user thread type" do
      assert GetListReminder.get_path(:user) == "/api/board/oneone/list"
    end

    test "returns group path for :group thread type" do
      assert GetListReminder.get_path(:group) == "/api/board/listReminder"
    end
  end

  describe "build_params/5 for user" do
    test "builds correct params for user thread" do
      {:ok, params} = GetListReminder.build_params("user_123", :user, 1, 20, "test-imei")

      assert Map.has_key?(params, :objectData)
      refute Map.has_key?(params, :imei)

      object_data = Jason.decode!(params.objectData)
      assert object_data["uid"] == "user_123"
      assert object_data["board_type"] == 1
      assert object_data["page"] == 1
      assert object_data["count"] == 20
      assert object_data["last_id"] == 0
      assert object_data["last_type"] == 0
    end

    test "accepts custom page and count" do
      {:ok, params} = GetListReminder.build_params("user_123", :user, 3, 50, "test-imei")

      object_data = Jason.decode!(params.objectData)
      assert object_data["page"] == 3
      assert object_data["count"] == 50
    end
  end

  describe "build_params/5 for group" do
    test "builds correct params for group thread" do
      {:ok, params} = GetListReminder.build_params("group_456", :group, 1, 20, "test-imei")

      assert Map.has_key?(params, :objectData)
      assert params.imei == "test-imei"

      object_data = Jason.decode!(params.objectData)
      assert object_data["group_id"] == "group_456"
      assert object_data["board_type"] == 1
      assert object_data["page"] == 1
      assert object_data["count"] == 20
      assert object_data["last_id"] == 0
      assert object_data["last_type"] == 0
    end
  end

  describe "build_base_url/2" do
    test "builds correct base URL for user thread", %{session: session} do
      url = GetListReminder.build_base_url(session, :user)

      assert url =~ "https://board.zalo.me/api/board/oneone/list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds correct base URL for group thread", %{session: session} do
      url = GetListReminder.build_base_url(session, :group)

      assert url =~ "https://board.zalo.me/api/board/listReminder"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params for user", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetListReminder.build_url(session, :user, encrypted)

      assert url =~ "https://board.zalo.me/api/board/oneone/list"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
    end

    test "builds URL with encrypted params for group", %{session: session} do
      encrypted = "encryptedParamsString456"
      url = GetListReminder.build_url(session, :group, encrypted)

      assert url =~ "https://board.zalo.me/api/board/listReminder"
      assert url =~ "params=encryptedParamsString456"
      assert url =~ "zpw_ver=645"
    end
  end

  describe "call/5 validation" do
    test "raises when group_board service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert_raise RuntimeError, ~r/Service URL not found for group_board/, fn ->
        GetListReminder.call("thread_123", :user, session_no_service, credentials)
      end
    end

    test "raises for group thread when service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert_raise RuntimeError, ~r/Service URL not found for group_board/, fn ->
        GetListReminder.call("group_456", :group, session_no_service, credentials)
      end
    end
  end
end
