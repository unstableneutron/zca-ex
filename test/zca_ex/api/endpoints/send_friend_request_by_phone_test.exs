defmodule ZcaEx.Api.Endpoints.SendFriendRequestByPhoneTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SendFriendRequestByPhone
  alias ZcaEx.Error

  describe "extract_user_id (via lookup)" do
    setup do
      session = %ZcaEx.Account.Session{
        uid: "test-uid",
        secret_key: Base.encode64(:crypto.strong_rand_bytes(32)),
        api_type: 30,
        api_version: 645,
        zpw_service_map: %{
          "friend" => ["https://tt-friend-wpa.chat.zalo.me"]
        }
      }

      credentials = %ZcaEx.Account.Credentials{
        imei: "test-imei-123",
        user_agent: "Test/1.0",
        cookies: %{},
        language: "vi"
      }

      {:ok, session: session, credentials: credentials}
    end

    test "returns error when user has hidden profile" do
      user = %{
        uid: "",
        global_id: "ABC123DEF456",
        zalo_name: "Test User",
        display_name: "Test",
        avatar: "https://example.com/avatar.jpg",
        status: "Hello"
      }

      result = SendFriendRequestByPhone.extract_user_id_for_test(user)
      assert {:error, %Error{code: :user_id_hidden}} = result
    end

    test "returns ok when user has visible profile" do
      user = %{
        uid: "1234567890",
        global_id: "ABC123DEF456",
        zalo_name: "Test User",
        display_name: "Test",
        avatar: "https://example.com/avatar.jpg",
        status: "Hello"
      }

      result = SendFriendRequestByPhone.extract_user_id_for_test(user)
      assert {:ok, "1234567890"} = result
    end
  end
end
