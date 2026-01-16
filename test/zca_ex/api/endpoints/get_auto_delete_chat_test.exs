defmodule ZcaEx.Api.Endpoints.GetAutoDeleteChatTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetAutoDeleteChat
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

  describe "build_params/0" do
    test "returns empty map" do
      assert GetAutoDeleteChat.build_params() == %{}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetAutoDeleteChat.build_base_url(session)

      assert url == "https://conversation.zalo.me/api/conv/autodelete/getConvers"
    end
  end

  describe "build_url/1" do
    test "builds correct URL with session params", %{session: session} do
      url = GetAutoDeleteChat.build_url(session)

      assert url =~ "https://conversation.zalo.me/api/conv/autodelete/getConvers"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "uses conversation service", %{session: session} do
      url = GetAutoDeleteChat.build_url(session)

      assert url =~ "conversation.zalo.me"
    end
  end

  describe "transform_response/1" do
    test "transforms empty convers list" do
      result = GetAutoDeleteChat.transform_response(%{"convers" => []})

      assert result == %{convers: []}
    end

    test "transforms convers with string keys" do
      data = %{
        "convers" => [
          %{"destId" => "user123", "isGroup" => false, "ttl" => 86400, "createdAt" => 1_700_000_000}
        ]
      }

      result = GetAutoDeleteChat.transform_response(data)

      assert result == %{
               convers: [
                 %{dest_id: "user123", is_group: false, ttl: 86400, created_at: 1_700_000_000}
               ]
             }
    end

    test "transforms convers with atom keys" do
      data = %{
        convers: [
          %{destId: "group456", isGroup: true, ttl: 3600, createdAt: 1_700_000_001}
        ]
      }

      result = GetAutoDeleteChat.transform_response(data)

      assert result == %{
               convers: [
                 %{dest_id: "group456", is_group: true, ttl: 3600, created_at: 1_700_000_001}
               ]
             }
    end

    test "handles missing convers key" do
      result = GetAutoDeleteChat.transform_response(%{})

      assert result == %{convers: []}
    end
  end

  describe "transform_entry/1" do
    test "transforms entry with boolean isGroup true" do
      entry = %{"destId" => "abc", "isGroup" => true, "ttl" => 100, "createdAt" => 123}

      result = GetAutoDeleteChat.transform_entry(entry)

      assert result.is_group == true
    end

    test "transforms entry with boolean isGroup false" do
      entry = %{"destId" => "abc", "isGroup" => false, "ttl" => 100, "createdAt" => 123}

      result = GetAutoDeleteChat.transform_entry(entry)

      assert result.is_group == false
    end

    test "transforms entry with integer isGroup 1" do
      entry = %{"destId" => "abc", "isGroup" => 1, "ttl" => 100, "createdAt" => 123}

      result = GetAutoDeleteChat.transform_entry(entry)

      assert result.is_group == true
    end

    test "transforms entry with integer isGroup 0" do
      entry = %{"destId" => "abc", "isGroup" => 0, "ttl" => 100, "createdAt" => 123}

      result = GetAutoDeleteChat.transform_entry(entry)

      assert result.is_group == false
    end
  end

  describe "call/2 service URL handling" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetAutoDeleteChat.call(session_no_service, credentials)
      end
    end

    test "raises when conversation service missing", %{session: session, credentials: credentials} do
      session_wrong_service = %{session | zpw_service_map: %{"group" => ["https://group.zalo.me"]}}

      assert_raise RuntimeError, ~r/Service URL not found for conversation/, fn ->
        GetAutoDeleteChat.call(session_wrong_service, credentials)
      end
    end
  end
end
