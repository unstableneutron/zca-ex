defmodule ZcaEx.Api.Endpoints.GetSettingsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetSettings
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

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetSettings.build_base_url(session)

      assert url =~ "https://wpa.chat.zalo.me/api/setting/me"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetSettings.build_url(session, encrypted)

      assert url =~ "https://wpa.chat.zalo.me/api/setting/me"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{
        "view_birthday" => 1,
        "show_online_status" => 1,
        "display_seen_status" => 0,
        "receive_message" => 2,
        "accept_stranger_call" => 3,
        "add_friend_via_phone" => 1,
        "add_friend_via_qr" => 1,
        "add_friend_via_group" => 0,
        "add_friend_via_contact" => 1,
        "display_on_recommend_friend" => 0,
        "archivedChatStatus" => 1,
        "quickMessageStatus" => 0
      }

      result = GetSettings.transform_response(data)

      assert result.view_birthday == 1
      assert result.show_online_status == 1
      assert result.display_seen_status == 0
      assert result.receive_message == 2
      assert result.accept_call == 3
      assert result.add_friend_via_phone == 1
      assert result.add_friend_via_qr == 1
      assert result.add_friend_via_group == 0
      assert result.add_friend_via_contact == 1
      assert result.display_on_recommend_friend == 0
      assert result.archived_chat == 1
      assert result.quick_message == 0
      assert result.raw == data
    end

    test "transforms response with atom keys" do
      data = %{
        view_birthday: 2,
        show_online_status: 0,
        display_seen_status: 1,
        receive_message: 1,
        accept_stranger_call: 4,
        add_friend_via_phone: 0,
        add_friend_via_qr: 0,
        add_friend_via_group: 1,
        add_friend_via_contact: 0,
        display_on_recommend_friend: 1,
        archivedChatStatus: 0,
        quickMessageStatus: 1
      }

      result = GetSettings.transform_response(data)

      assert result.view_birthday == 2
      assert result.show_online_status == 0
      assert result.display_seen_status == 1
      assert result.receive_message == 1
      assert result.accept_call == 4
      assert result.add_friend_via_phone == 0
      assert result.add_friend_via_qr == 0
      assert result.add_friend_via_group == 1
      assert result.add_friend_via_contact == 0
      assert result.display_on_recommend_friend == 1
      assert result.archived_chat == 0
      assert result.quick_message == 1
      assert result.raw == data
    end

    test "handles partial response" do
      data = %{
        "view_birthday" => 1,
        "show_online_status" => 1
      }

      result = GetSettings.transform_response(data)

      assert result.view_birthday == 1
      assert result.show_online_status == 1
      assert result.display_seen_status == nil
      assert result.receive_message == nil
      assert result.accept_call == nil
      assert result.add_friend_via_phone == nil
      assert result.add_friend_via_qr == nil
      assert result.add_friend_via_group == nil
      assert result.add_friend_via_contact == nil
      assert result.display_on_recommend_friend == nil
      assert result.archived_chat == nil
      assert result.quick_message == nil
      assert result.raw == data
    end

    test "handles empty response" do
      data = %{}

      result = GetSettings.transform_response(data)

      assert result.view_birthday == nil
      assert result.show_online_status == nil
      assert result.display_seen_status == nil
      assert result.receive_message == nil
      assert result.accept_call == nil
      assert result.add_friend_via_phone == nil
      assert result.add_friend_via_qr == nil
      assert result.add_friend_via_group == nil
      assert result.add_friend_via_contact == nil
      assert result.display_on_recommend_friend == nil
      assert result.archived_chat == nil
      assert result.quick_message == nil
      assert result.raw == data
    end

    test "preserves raw data including extra fields" do
      data = %{
        "view_birthday" => 1,
        "extra_field" => "extra_value",
        "another_field" => 42
      }

      result = GetSettings.transform_response(data)

      assert result.raw["extra_field"] == "extra_value"
      assert result.raw["another_field"] == 42
    end

    test "handles zero values correctly" do
      data = %{
        "view_birthday" => 0,
        "show_online_status" => 0,
        "display_seen_status" => 0
      }

      result = GetSettings.transform_response(data)

      assert result.view_birthday == 0
      assert result.show_online_status == 0
      assert result.display_seen_status == 0
    end
  end
end
