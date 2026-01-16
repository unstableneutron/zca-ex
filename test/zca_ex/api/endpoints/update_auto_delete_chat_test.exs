defmodule ZcaEx.Api.Endpoints.UpdateAutoDeleteChatTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateAutoDeleteChat
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "conversation" => ["https://tt-convers-wpa.chat.zalo.me"]
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

  describe "ttl_to_value/1" do
    test "converts :no_delete to 0" do
      assert {:ok, 0} = UpdateAutoDeleteChat.ttl_to_value(:no_delete)
    end

    test "converts :one_day to 86400000" do
      assert {:ok, 86_400_000} = UpdateAutoDeleteChat.ttl_to_value(:one_day)
    end

    test "converts :seven_days to 604800000" do
      assert {:ok, 604_800_000} = UpdateAutoDeleteChat.ttl_to_value(:seven_days)
    end

    test "converts :fourteen_days to 1209600000" do
      assert {:ok, 1_209_600_000} = UpdateAutoDeleteChat.ttl_to_value(:fourteen_days)
    end

    test "accepts non-negative integers" do
      assert {:ok, 0} = UpdateAutoDeleteChat.ttl_to_value(0)
      assert {:ok, 12345} = UpdateAutoDeleteChat.ttl_to_value(12345)
      assert {:ok, 86_400_000} = UpdateAutoDeleteChat.ttl_to_value(86_400_000)
    end

    test "rejects negative integers" do
      assert {:error, error} = UpdateAutoDeleteChat.ttl_to_value(-1)
      assert error.message =~ "Invalid TTL"
    end

    test "rejects invalid atoms" do
      assert {:error, error} = UpdateAutoDeleteChat.ttl_to_value(:invalid)
      assert error.message =~ "Invalid TTL"
    end

    test "rejects non-integer/non-atom values" do
      assert {:error, error} = UpdateAutoDeleteChat.ttl_to_value("12345")
      assert error.message =~ "Invalid TTL"
    end
  end

  describe "thread_type_to_int/1" do
    test "converts :group to 1" do
      assert UpdateAutoDeleteChat.thread_type_to_int(:group) == 1
    end

    test "converts :user to 0" do
      assert UpdateAutoDeleteChat.thread_type_to_int(:user) == 0
    end

    test "defaults to 0 for any other value" do
      assert UpdateAutoDeleteChat.thread_type_to_int(nil) == 0
      assert UpdateAutoDeleteChat.thread_type_to_int(:other) == 0
    end
  end

  describe "build_params/4" do
    test "builds correct params for user thread", %{credentials: credentials} do
      params = UpdateAutoDeleteChat.build_params(86_400_000, "thread123", :user, credentials)

      assert params == %{
               threadId: "thread123",
               isGroup: 0,
               ttl: 86_400_000,
               clientLang: "vi"
             }
    end

    test "builds correct params for group thread", %{credentials: credentials} do
      params = UpdateAutoDeleteChat.build_params(604_800_000, "group456", :group, credentials)

      assert params == %{
               threadId: "group456",
               isGroup: 1,
               ttl: 604_800_000,
               clientLang: "vi"
             }
    end

    test "builds params with no_delete ttl", %{credentials: credentials} do
      params = UpdateAutoDeleteChat.build_params(0, "thread123", :user, credentials)

      assert params.ttl == 0
    end

    test "uses credentials language", %{credentials: credentials} do
      params = UpdateAutoDeleteChat.build_params(0, "thread123", :user, credentials)

      assert params.clientLang == "vi"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL" do
      url = UpdateAutoDeleteChat.build_base_url("https://tt-convers-wpa.chat.zalo.me")

      assert url == "https://tt-convers-wpa.chat.zalo.me/api/conv/autodelete/updateConvers"
    end
  end

  describe "build_url/2" do
    test "builds full URL with session params", %{session: session} do
      url = UpdateAutoDeleteChat.build_url("https://tt-convers-wpa.chat.zalo.me", session)

      assert url =~ "https://tt-convers-wpa.chat.zalo.me/api/conv/autodelete/updateConvers"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "uses custom api_type and api_version from session" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{"conversation" => ["https://tt-convers-wpa.chat.zalo.me"]},
        api_type: 31,
        api_version: 650
      }

      url = UpdateAutoDeleteChat.build_url("https://tt-convers-wpa.chat.zalo.me", session)

      assert url =~ "zpw_ver=650"
      assert url =~ "zpw_type=31"
    end
  end

  describe "call/5 validation" do
    test "returns error when thread_id is empty", %{session: session, credentials: credentials} do
      assert {:error, error} =
               UpdateAutoDeleteChat.call(session, credentials, :one_day, "", :user)

      assert error.message =~ "Invalid thread_id"
    end

    test "returns error when thread_id is nil", %{session: session, credentials: credentials} do
      assert {:error, error} =
               UpdateAutoDeleteChat.call(session, credentials, :one_day, nil, :user)

      assert error.message =~ "Invalid thread_id"
    end

    test "returns error when ttl is invalid", %{session: session, credentials: credentials} do
      assert {:error, error} =
               UpdateAutoDeleteChat.call(session, credentials, :invalid_ttl, "thread123", :user)

      assert error.message =~ "Invalid TTL"
    end

    test "returns error when conversation service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert {:error, error} =
               UpdateAutoDeleteChat.call(
                 session_no_service,
                 credentials,
                 :one_day,
                 "thread123",
                 :user
               )

      assert error.message =~ "Service URL not found"
    end
  end
end
