defmodule ZcaEx.Api.Endpoints.AddQuickMessageTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.AddQuickMessage
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

  describe "build_params/3" do
    test "builds correct params structure", %{credentials: credentials} do
      params = AddQuickMessage.build_params("hello", "Hello World!", credentials)

      assert params.keyword == "hello"
      assert params.message == %{title: "Hello World!", params: ""}
      assert params.type == 0
      assert params.imei == "test-imei-12345"
    end
  end

  describe "build_url/3" do
    test "builds correct URL with encrypted params", %{session: session} do
      url = AddQuickMessage.build_url("https://quickmsg.zalo.me", session, "encrypted123")

      assert url =~ "https://quickmsg.zalo.me/api/quickmessage/create"
      assert url =~ "params=encrypted123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "add/4 validation" do
    test "returns error for empty keyword", %{session: session, credentials: credentials} do
      result = AddQuickMessage.add("", "Title", session, credentials)

      assert {:error, error} = result
      assert error.message == "keyword must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil keyword", %{session: session, credentials: credentials} do
      result = AddQuickMessage.add(nil, "Title", session, credentials)

      assert {:error, error} = result
      assert error.message == "keyword must be a non-empty string"
    end

    test "returns error for non-string keyword", %{session: session, credentials: credentials} do
      result = AddQuickMessage.add(123, "Title", session, credentials)

      assert {:error, error} = result
      assert error.message == "keyword must be a non-empty string"
    end

    test "returns error for empty title", %{session: session, credentials: credentials} do
      result = AddQuickMessage.add("keyword", "", session, credentials)

      assert {:error, error} = result
      assert error.message == "title must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil title", %{session: session, credentials: credentials} do
      result = AddQuickMessage.add("keyword", nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "title must be a non-empty string"
    end

    test "returns error for non-string title", %{session: session, credentials: credentials} do
      result = AddQuickMessage.add("keyword", 456, session, credentials)

      assert {:error, error} = result
      assert error.message == "title must be a non-empty string"
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = AddQuickMessage.add("keyword", "Title", session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "quick_message service URL not found"
      assert error.code == :service_not_found
    end
  end
end
