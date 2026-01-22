defmodule ZcaEx.Api.Endpoints.GetPinConversationsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetPinConversations
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "conversation" => ["https://conversation.zalo.me"]
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
    test "builds correct params with imei" do
      params = GetPinConversations.build_params("test-imei")

      assert params.imei == "test-imei"
      assert map_size(params) == 1
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetPinConversations.build_base_url(session)

      assert url =~ "https://conversation.zalo.me/api/pinconvers/list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "uses conversation service", %{session: session} do
      url = GetPinConversations.build_base_url(session)

      assert url =~ "conversation.zalo.me"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetPinConversations.build_url(session, encrypted)

      assert url =~ "https://conversation.zalo.me/api/pinconvers/list"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{"conversations" => ["conv1", "conv2"], "version" => 42}
      result = GetPinConversations.transform_response(data)

      assert result.conversations == ["conv1", "conv2"]
      assert result.version == 42
    end

    test "transforms response with atom keys" do
      data = %{conversations: ["conv1"], version: 10}
      result = GetPinConversations.transform_response(data)

      assert result.conversations == ["conv1"]
      assert result.version == 10
    end

    test "handles missing fields with defaults" do
      result = GetPinConversations.transform_response(%{})

      assert result.conversations == []
      assert result.version == 0
    end
  end

  describe "call/2 service URL handling" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetPinConversations.call(session_no_service, credentials)
      end
    end

    test "raises when conversation service missing", %{session: session, credentials: credentials} do
      session_wrong_service = %{
        session
        | zpw_service_map: %{"profile" => ["https://profile.zalo.me"]}
      }

      assert_raise RuntimeError, ~r/Service URL not found for conversation/, fn ->
        GetPinConversations.call(session_wrong_service, credentials)
      end
    end
  end
end
