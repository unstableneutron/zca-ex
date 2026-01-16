defmodule ZcaEx.Api.Endpoints.GetHiddenConversationsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetHiddenConversations
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
      params = GetHiddenConversations.build_params("test-imei-12345")

      assert params == %{imei: "test-imei-12345"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetHiddenConversations.build_base_url(session)

      assert url =~ "https://conversation.zalo.me/api/hiddenconvers/get-all"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetHiddenConversations.build_url(session, encrypted)

      assert url =~ "https://conversation.zalo.me/api/hiddenconvers/get-all"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms API response to structured format" do
      data = %{
        "pin" => "1234",
        "threads" => [
          %{"thread_id" => "thread1", "is_group" => 0},
          %{"thread_id" => "thread2", "is_group" => 1}
        ]
      }

      result = GetHiddenConversations.transform_response(data)

      assert result.pin == "1234"
      assert length(result.threads) == 2
      assert Enum.at(result.threads, 0) == %{thread_id: "thread1", is_group: false}
      assert Enum.at(result.threads, 1) == %{thread_id: "thread2", is_group: true}
    end

    test "handles missing fields with defaults" do
      data = %{}

      result = GetHiddenConversations.transform_response(data)

      assert result.pin == ""
      assert result.threads == []
    end

    test "handles atom keys" do
      data = %{
        pin: "5678",
        threads: [
          %{thread_id: "thread3", is_group: 1}
        ]
      }

      result = GetHiddenConversations.transform_response(data)

      assert result.pin == "5678"
      assert length(result.threads) == 1
      assert Enum.at(result.threads, 0) == %{thread_id: "thread3", is_group: true}
    end
  end

  describe "transform_thread/1" do
    test "converts is_group 0 to false" do
      thread = %{"thread_id" => "abc123", "is_group" => 0}

      result = GetHiddenConversations.transform_thread(thread)

      assert result == %{thread_id: "abc123", is_group: false}
    end

    test "converts is_group 1 to true" do
      thread = %{"thread_id" => "xyz789", "is_group" => 1}

      result = GetHiddenConversations.transform_thread(thread)

      assert result == %{thread_id: "xyz789", is_group: true}
    end

    test "handles missing is_group as false" do
      thread = %{"thread_id" => "test123"}

      result = GetHiddenConversations.transform_thread(thread)

      assert result == %{thread_id: "test123", is_group: false}
    end

    test "handles atom keys" do
      thread = %{thread_id: "atom123", is_group: 1}

      result = GetHiddenConversations.transform_thread(thread)

      assert result == %{thread_id: "atom123", is_group: true}
    end
  end

  describe "call/2 validation" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetHiddenConversations.call(session_no_service, credentials)
      end
    end
  end
end
