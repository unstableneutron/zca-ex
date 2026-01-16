defmodule ZcaEx.Api.Endpoints.GetBizAccountTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetBizAccount
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "profile" => ["https://profile.zalo.me"]
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
    test "builds correct params" do
      params = GetBizAccount.build_params("friend123")

      assert params.fid == "friend123"
    end
  end

  describe "build_url/2" do
    test "builds correct URL", %{session: session} do
      url = GetBizAccount.build_url("https://profile.zalo.me", session)

      assert url =~ "https://profile.zalo.me/api/social/friend/get-bizacc"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "get/3 validation" do
    test "returns error for empty friend_id", %{session: session, credentials: credentials} do
      result = GetBizAccount.get("", session, credentials)

      assert {:error, error} = result
      assert error.message == "friend_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil friend_id", %{session: session, credentials: credentials} do
      result = GetBizAccount.get(nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "friend_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for non-string friend_id", %{session: session, credentials: credentials} do
      result = GetBizAccount.get(123, session, credentials)

      assert {:error, error} = result
      assert error.message == "friend_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = GetBizAccount.get("friend123", session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "profile service URL not found"
      assert error.code == :service_not_found
    end
  end
end
