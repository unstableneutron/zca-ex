defmodule ZcaEx.Api.Endpoints.GetUserInfoTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetUserInfo
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "profile" => ["https://profile.zalo.me"]
      },
      extra_ver: %{"phonebook" => 100},
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

  describe "normalize_user_ids/1" do
    test "adds _0 suffix to plain user IDs" do
      ids = ["12345", "67890"]
      result = GetUserInfo.normalize_user_ids(ids)
      assert result == ["12345_0", "67890_0"]
    end

    test "preserves IDs that already have suffix" do
      ids = ["12345_0", "67890_1"]
      result = GetUserInfo.normalize_user_ids(ids)
      assert result == ["12345_0", "67890_1"]
    end

    test "handles mixed IDs" do
      ids = ["12345", "67890_0", "11111"]
      result = GetUserInfo.normalize_user_ids(ids)
      assert result == ["12345_0", "67890_0", "11111_0"]
    end

    test "handles empty list" do
      assert GetUserInfo.normalize_user_ids([]) == []
    end
  end

  describe "build_url/1" do
    test "builds correct URL with session params", %{session: session} do
      assert {:ok, url} = GetUserInfo.build_url(session)

      assert url =~ "https://profile.zalo.me/api/social/friend/getprofiles/v2"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_params/3" do
    test "builds correct params map", %{session: session, credentials: credentials} do
      user_ids = ["user1", "user2"]
      params = GetUserInfo.build_params(user_ids, session, credentials)

      assert params.phonebook_version == 100
      assert params.friend_pversion_map == ["user1_0", "user2_0"]
      assert params.avatar_size == 120
      assert params.language == "vi"
      assert params.show_online_status == 1
      assert params.imei == "test-imei-12345"
    end

    test "handles nil extra_ver", %{credentials: credentials} do
      session = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{"profile" => ["https://profile.zalo.me"]},
        extra_ver: nil,
        api_type: 30,
        api_version: 645
      }

      params = GetUserInfo.build_params(["user1"], session, credentials)
      assert params.phonebook_version == 0
    end
  end

  describe "call/3 input validation" do
    test "returns error when service URL not found" do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      credentials = %Credentials{
        imei: "test",
        user_agent: "test",
        cookies: [],
        language: "vi"
      }

      assert {:error, error} = GetUserInfo.call("single_user", session_no_service, credentials)
      assert error.message =~ "Service URL not found"
    end
  end
end
