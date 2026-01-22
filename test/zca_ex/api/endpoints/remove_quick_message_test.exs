defmodule ZcaEx.Api.Endpoints.RemoveQuickMessageTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.RemoveQuickMessage
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

  describe "build_params/2" do
    test "builds correct params with list", %{credentials: credentials} do
      params = RemoveQuickMessage.build_params([1, 2, 3], credentials)

      assert params.itemIds == [1, 2, 3]
      assert params.imei == "test-imei-12345"
    end

    test "builds correct params with single item wrapped in list", %{credentials: credentials} do
      params = RemoveQuickMessage.build_params([123], credentials)

      assert params.itemIds == [123]
      assert params.imei == "test-imei-12345"
    end
  end

  describe "build_url/3" do
    test "builds correct URL with encrypted params", %{session: session} do
      url = RemoveQuickMessage.build_url("https://quickmsg.zalo.me", "encrypted123", session)

      assert url =~ "https://quickmsg.zalo.me/api/quickmessage/delete"
      assert url =~ "params=encrypted123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "remove/3 validation" do
    test "accepts single positive integer returns error for missing service", %{
      session: session,
      credentials: credentials
    } do
      session_no_service = %{session | zpw_service_map: %{}}
      result = RemoveQuickMessage.remove(123, session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "quick_message service URL not found"
      assert error.code == :service_not_found
    end

    test "accepts list of positive integers returns error for missing service", %{
      session: session,
      credentials: credentials
    } do
      session_no_service = %{session | zpw_service_map: %{}}
      result = RemoveQuickMessage.remove([1, 2, 3], session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "quick_message service URL not found"
      assert error.code == :service_not_found
    end

    test "returns error for zero item_id", %{session: session, credentials: credentials} do
      result = RemoveQuickMessage.remove(0, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "positive integer"
      assert error.code == :invalid_input
    end

    test "returns error for negative item_id", %{session: session, credentials: credentials} do
      result = RemoveQuickMessage.remove(-1, session, credentials)

      assert {:error, error} = result
      assert error.code == :invalid_input
    end

    test "returns error for empty list", %{session: session, credentials: credentials} do
      result = RemoveQuickMessage.remove([], session, credentials)

      assert {:error, error} = result
      assert error.code == :invalid_input
    end

    test "returns error for list with invalid items", %{
      session: session,
      credentials: credentials
    } do
      result = RemoveQuickMessage.remove([1, 0, 3], session, credentials)

      assert {:error, error} = result
      assert error.code == :invalid_input
    end

    test "returns error for string item_id", %{session: session, credentials: credentials} do
      result = RemoveQuickMessage.remove("123", session, credentials)

      assert {:error, error} = result
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL with valid input", %{
      session: session,
      credentials: credentials
    } do
      session_no_service = %{session | zpw_service_map: %{}}
      result = RemoveQuickMessage.remove(123, session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "quick_message service URL not found"
      assert error.code == :service_not_found
    end
  end
end
