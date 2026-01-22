defmodule ZcaEx.Api.Endpoints.UpdateGroupSettingsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateGroupSettings
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group" => ["https://group.zalo.me"]
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
    test "builds params with all default values when settings is empty", %{
      credentials: credentials
    } do
      params = UpdateGroupSettings.build_params(%{}, "group123", credentials)

      assert params == %{
               blockName: 0,
               signAdminMsg: 0,
               setTopicOnly: 0,
               enableMsgHistory: 0,
               joinAppr: 0,
               lockCreatePost: 0,
               lockCreatePoll: 0,
               lockSendMsg: 0,
               lockViewMember: 0,
               bannFeature: 0,
               dirtyMedia: 0,
               banDuration: 0,
               blocked_members: [],
               grid: "group123",
               imei: "test-imei-12345"
             }
    end

    test "converts true boolean values to 1", %{credentials: credentials} do
      settings = %{
        block_name: true,
        sign_admin_msg: true,
        set_topic_only: true,
        enable_msg_history: true,
        join_appr: true,
        lock_create_post: true,
        lock_create_poll: true,
        lock_send_msg: true,
        lock_view_member: true
      }

      params = UpdateGroupSettings.build_params(settings, "group123", credentials)

      assert params.blockName == 1
      assert params.signAdminMsg == 1
      assert params.setTopicOnly == 1
      assert params.enableMsgHistory == 1
      assert params.joinAppr == 1
      assert params.lockCreatePost == 1
      assert params.lockCreatePoll == 1
      assert params.lockSendMsg == 1
      assert params.lockViewMember == 1
    end

    test "converts false boolean values to 0", %{credentials: credentials} do
      settings = %{
        block_name: false,
        sign_admin_msg: false,
        lock_send_msg: false
      }

      params = UpdateGroupSettings.build_params(settings, "group123", credentials)

      assert params.blockName == 0
      assert params.signAdminMsg == 0
      assert params.lockSendMsg == 0
    end

    test "handles mixed true/false settings", %{credentials: credentials} do
      settings = %{
        block_name: true,
        sign_admin_msg: false,
        enable_msg_history: true,
        lock_send_msg: false
      }

      params = UpdateGroupSettings.build_params(settings, "group123", credentials)

      assert params.blockName == 1
      assert params.signAdminMsg == 0
      assert params.enableMsgHistory == 1
      assert params.lockSendMsg == 0
    end

    test "always includes default values for unimplemented options", %{credentials: credentials} do
      params = UpdateGroupSettings.build_params(%{block_name: true}, "group123", credentials)

      assert params.bannFeature == 0
      assert params.dirtyMedia == 0
      assert params.banDuration == 0
      assert params.blocked_members == []
    end

    test "includes grid and imei", %{credentials: credentials} do
      params = UpdateGroupSettings.build_params(%{}, "my-group-id", credentials)

      assert params.grid == "my-group-id"
      assert params.imei == "test-imei-12345"
    end
  end

  describe "build_url/3" do
    test "builds correct URL with encrypted params in query", %{session: session} do
      url = UpdateGroupSettings.build_url("https://group.zalo.me", "encrypted123", session)

      assert url =~ "https://group.zalo.me/api/group/setting/update"
      assert url =~ "params=encrypted123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "uses custom api_type and api_version from session" do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{"group" => ["https://group.zalo.me"]},
        api_type: 31,
        api_version: 650
      }

      url = UpdateGroupSettings.build_url("https://group.zalo.me", "enc", session)

      assert url =~ "zpw_ver=650"
      assert url =~ "zpw_type=31"
    end

    test "properly encodes special characters in encrypted params", %{session: session} do
      url = UpdateGroupSettings.build_url("https://group.zalo.me", "abc+def/ghi=", session)

      assert url =~ "params=abc%2Bdef%2Fghi%3D"
    end
  end

  describe "call/4 input validation" do
    test "returns error when service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert {:error, error} =
               UpdateGroupSettings.call(%{}, "group123", session_no_service, credentials)

      assert error.message =~ "Service URL not found"
    end
  end
end
