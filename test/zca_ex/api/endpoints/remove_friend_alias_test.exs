defmodule ZcaEx.Api.Endpoints.RemoveFriendAliasTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.RemoveFriendAlias
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "alias" => ["https://alias.zalo.me"]
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
    test "builds params with friend_id only" do
      params = RemoveFriendAlias.build_params("friend123")

      assert params.friendId == "friend123"
      assert map_size(params) == 1
    end
  end

  describe "build_base_url/1" do
    test "builds correct URL with session params", %{session: session} do
      url = RemoveFriendAlias.build_base_url(session)

      assert url =~ "https://alias.zalo.me/api/alias/remove"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "validate_friend_id/1" do
    test "returns :ok for valid friend_id" do
      assert :ok = RemoveFriendAlias.validate_friend_id("friend123")
    end

    test "returns error for nil friend_id" do
      assert {:error, error} = RemoveFriendAlias.validate_friend_id(nil)
      assert error.message == "friend_id is required"
    end

    test "returns error for empty friend_id" do
      assert {:error, error} = RemoveFriendAlias.validate_friend_id("")
      assert error.message == "friend_id is required"
    end

    test "returns error for non-string friend_id" do
      assert {:error, error} = RemoveFriendAlias.validate_friend_id(123)
      assert error.message == "friend_id must be a string"
    end
  end
end
