defmodule ZcaEx.Api.Endpoints.UpdateQuickMessageTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateQuickMessage
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "quick_message" => ["https://quickmsg.zalo.me"]
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
    test "builds correct params structure", %{credentials: credentials} do
      params = UpdateQuickMessage.build_params(123, "hello", "Hello World!", credentials)

      assert params.itemId == 123
      assert params.keyword == "hello"
      assert params.message == %{title: "Hello World!", params: ""}
      assert params.type == 0
      assert params.imei == "test-imei-12345"
    end
  end

  describe "build_url/3" do
    test "builds correct URL with encrypted params", %{session: session} do
      url = UpdateQuickMessage.build_url("https://quickmsg.zalo.me", "encrypted123", session)

      assert url =~ "https://quickmsg.zalo.me/api/quickmessage/update"
      assert url =~ "params=encrypted123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "update/5 validation" do
    test "returns error for zero item_id", %{session: session, credentials: credentials} do
      result = UpdateQuickMessage.update(0, "keyword", "Title", session, credentials)

      assert {:error, error} = result
      assert error.message == "item_id must be a positive integer"
      assert error.code == :invalid_input
    end

    test "returns error for negative item_id", %{session: session, credentials: credentials} do
      result = UpdateQuickMessage.update(-1, "keyword", "Title", session, credentials)

      assert {:error, error} = result
      assert error.message == "item_id must be a positive integer"
    end

    test "returns error for non-integer item_id", %{session: session, credentials: credentials} do
      result = UpdateQuickMessage.update("123", "keyword", "Title", session, credentials)

      assert {:error, error} = result
      assert error.message == "item_id must be a positive integer"
    end

    test "returns error for empty keyword", %{session: session, credentials: credentials} do
      result = UpdateQuickMessage.update(123, "", "Title", session, credentials)

      assert {:error, error} = result
      assert error.message == "keyword must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil keyword", %{session: session, credentials: credentials} do
      result = UpdateQuickMessage.update(123, nil, "Title", session, credentials)

      assert {:error, error} = result
      assert error.message == "keyword must be a non-empty string"
    end

    test "returns error for empty title", %{session: session, credentials: credentials} do
      result = UpdateQuickMessage.update(123, "keyword", "", session, credentials)

      assert {:error, error} = result
      assert error.message == "title must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil title", %{session: session, credentials: credentials} do
      result = UpdateQuickMessage.update(123, "keyword", nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "title must be a non-empty string"
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = UpdateQuickMessage.update(123, "keyword", "Title", session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "quick_message service URL not found"
      assert error.code == :service_not_found
    end
  end
end
