defmodule ZcaEx.Api.Endpoints.UpdateSettingsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateSettings
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{},
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

  describe "validate_setting_type/1" do
    test "accepts :view_birthday" do
      assert :ok = UpdateSettings.validate_setting_type(:view_birthday)
    end

    test "accepts :show_online_status" do
      assert :ok = UpdateSettings.validate_setting_type(:show_online_status)
    end

    test "accepts :display_seen_status" do
      assert :ok = UpdateSettings.validate_setting_type(:display_seen_status)
    end

    test "accepts :receive_message" do
      assert :ok = UpdateSettings.validate_setting_type(:receive_message)
    end

    test "accepts :accept_call" do
      assert :ok = UpdateSettings.validate_setting_type(:accept_call)
    end

    test "accepts :add_friend_via_phone" do
      assert :ok = UpdateSettings.validate_setting_type(:add_friend_via_phone)
    end

    test "accepts :add_friend_via_qr" do
      assert :ok = UpdateSettings.validate_setting_type(:add_friend_via_qr)
    end

    test "accepts :add_friend_via_group" do
      assert :ok = UpdateSettings.validate_setting_type(:add_friend_via_group)
    end

    test "accepts :add_friend_via_contact" do
      assert :ok = UpdateSettings.validate_setting_type(:add_friend_via_contact)
    end

    test "accepts :display_on_recommend_friend" do
      assert :ok = UpdateSettings.validate_setting_type(:display_on_recommend_friend)
    end

    test "accepts :archived_chat" do
      assert :ok = UpdateSettings.validate_setting_type(:archived_chat)
    end

    test "accepts :quick_message" do
      assert :ok = UpdateSettings.validate_setting_type(:quick_message)
    end

    test "rejects invalid setting type" do
      assert {:error, error} = UpdateSettings.validate_setting_type(:invalid_setting)
      assert error.message == "Invalid setting type"
    end

    test "rejects string setting type" do
      assert {:error, error} = UpdateSettings.validate_setting_type("view_birthday")
      assert error.message == "Invalid setting type"
    end

    test "rejects nil" do
      assert {:error, error} = UpdateSettings.validate_setting_type(nil)
      assert error.message == "Invalid setting type"
    end
  end

  describe "build_params/2" do
    test "builds params for :view_birthday" do
      params = UpdateSettings.build_params(:view_birthday, 1)
      assert params == %{"view_birthday" => 1}
    end

    test "builds params for :show_online_status" do
      params = UpdateSettings.build_params(:show_online_status, 0)
      assert params == %{"show_online_status" => 0}
    end

    test "builds params for :display_seen_status" do
      params = UpdateSettings.build_params(:display_seen_status, 1)
      assert params == %{"display_seen_status" => 1}
    end

    test "builds params for :receive_message" do
      params = UpdateSettings.build_params(:receive_message, 2)
      assert params == %{"receive_message" => 2}
    end

    test "builds params for :accept_call with API key accept_stranger_call" do
      params = UpdateSettings.build_params(:accept_call, 3)
      assert params == %{"accept_stranger_call" => 3}
    end

    test "builds params for :add_friend_via_phone" do
      params = UpdateSettings.build_params(:add_friend_via_phone, 1)
      assert params == %{"add_friend_via_phone" => 1}
    end

    test "builds params for :add_friend_via_qr" do
      params = UpdateSettings.build_params(:add_friend_via_qr, 0)
      assert params == %{"add_friend_via_qr" => 0}
    end

    test "builds params for :add_friend_via_group" do
      params = UpdateSettings.build_params(:add_friend_via_group, 1)
      assert params == %{"add_friend_via_group" => 1}
    end

    test "builds params for :add_friend_via_contact" do
      params = UpdateSettings.build_params(:add_friend_via_contact, 0)
      assert params == %{"add_friend_via_contact" => 0}
    end

    test "builds params for :display_on_recommend_friend" do
      params = UpdateSettings.build_params(:display_on_recommend_friend, 1)
      assert params == %{"display_on_recommend_friend" => 1}
    end

    test "builds params for :archived_chat with API key archivedChatStatus" do
      params = UpdateSettings.build_params(:archived_chat, 1)
      assert params == %{"archivedChatStatus" => 1}
    end

    test "builds params for :quick_message with API key quickMessageStatus" do
      params = UpdateSettings.build_params(:quick_message, 0)
      assert params == %{"quickMessageStatus" => 0}
    end
  end

  describe "setting_key/1" do
    test "returns correct API key for :view_birthday" do
      assert UpdateSettings.setting_key(:view_birthday) == "view_birthday"
    end

    test "returns correct API key for :accept_call" do
      assert UpdateSettings.setting_key(:accept_call) == "accept_stranger_call"
    end

    test "returns correct API key for :archived_chat" do
      assert UpdateSettings.setting_key(:archived_chat) == "archivedChatStatus"
    end

    test "returns correct API key for :quick_message" do
      assert UpdateSettings.setting_key(:quick_message) == "quickMessageStatus"
    end
  end

  describe "setting_types/0" do
    test "returns all valid setting types" do
      types = UpdateSettings.setting_types()

      assert :view_birthday in types
      assert :show_online_status in types
      assert :display_seen_status in types
      assert :receive_message in types
      assert :accept_call in types
      assert :add_friend_via_phone in types
      assert :add_friend_via_qr in types
      assert :add_friend_via_group in types
      assert :add_friend_via_contact in types
      assert :display_on_recommend_friend in types
      assert :archived_chat in types
      assert :quick_message in types
      assert length(types) == 12
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = UpdateSettings.build_base_url(session)

      assert url =~ "https://wpa.chat.zalo.me/api/setting/update"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = UpdateSettings.build_url(session, encrypted)

      assert url =~ "https://wpa.chat.zalo.me/api/setting/update"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/4 validation" do
    test "returns error for invalid setting type", %{session: session, credentials: credentials} do
      assert {:error, error} = UpdateSettings.call(session, credentials, :invalid_type, 1)
      assert error.message == "Invalid setting type"
    end
  end
end
