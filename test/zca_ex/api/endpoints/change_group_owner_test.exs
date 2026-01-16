defmodule ZcaEx.Api.Endpoints.ChangeGroupOwnerTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.ChangeGroupOwner
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
    test "builds params with correct structure", %{credentials: credentials} do
      params = ChangeGroupOwner.build_params("member123", "group456", credentials)

      assert params.grid == "group456"
      assert params.newAdminId == "member123"
      assert params.imei == credentials.imei
      assert params.language == "vi"
    end

    test "uses default language when not set" do
      {:ok, creds_no_lang} =
        Credentials.new(
          imei: "test-imei",
          user_agent: "Mozilla/5.0 Test",
          cookies: []
        )

      params = ChangeGroupOwner.build_params("member123", "group456", creds_no_lang)
      assert params.language == "vi"
    end
  end

  describe "build_url/2" do
    test "builds correct URL with encrypted params", %{session: session} do
      encrypted_params = "encrypted_test_params"
      url = ChangeGroupOwner.build_url(session, encrypted_params)

      assert url =~ "https://group.zalo.me/api/group/change-owner"
      assert url =~ "params=encrypted_test_params"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/4 validation" do
    test "returns error for empty new_owner_id", %{session: session, credentials: credentials} do
      {:error, error} = ChangeGroupOwner.call("", "group123", session, credentials)
      assert error.message =~ "Missing new_owner_id"
    end

    test "returns error for nil new_owner_id", %{session: session, credentials: credentials} do
      {:error, error} = ChangeGroupOwner.call(nil, "group123", session, credentials)
      assert error.message =~ "Missing new_owner_id"
    end

    test "returns error for empty group_id", %{session: session, credentials: credentials} do
      {:error, error} = ChangeGroupOwner.call("member123", "", session, credentials)
      assert error.message =~ "Missing group_id"
    end

    test "returns error for nil group_id", %{session: session, credentials: credentials} do
      {:error, error} = ChangeGroupOwner.call("member123", nil, session, credentials)
      assert error.message =~ "Missing group_id"
    end
  end

  describe "service URL handling" do
    test "raises when service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        ChangeGroupOwner.call("member123", "group456", session_no_service, credentials)
      end
    end
  end
end
