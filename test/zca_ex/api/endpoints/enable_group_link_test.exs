defmodule ZcaEx.Api.Endpoints.EnableGroupLinkTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.EnableGroupLink
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group" => ["https://groupchat.zalo.me"]
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

  describe "build_params/2" do
    test "builds params with group_id and imei", %{credentials: credentials} do
      params = EnableGroupLink.build_params("group123", credentials)

      assert params.grid == "group123"
      assert params.imei == "test-imei-12345"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = EnableGroupLink.build_base_url(session)

      assert url == "https://groupchat.zalo.me/api/group/link/new"
    end
  end

  describe "build_url/2" do
    test "builds correct URL with encrypted params", %{session: session} do
      encrypted_params = "encrypted_test_params"
      url = EnableGroupLink.build_url(session, encrypted_params)

      assert url =~ "https://groupchat.zalo.me/api/group/link/new"
      assert url =~ "params=encrypted_test_params"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 input handling" do
    test "returns error when group_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "group_id cannot be empty", code: :invalid_input}} =
               EnableGroupLink.call("", session, credentials)
    end

    test "returns error when group_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "group_id cannot be empty", code: :invalid_input}} =
               EnableGroupLink.call(nil, session, credentials)
    end

    test "raises error when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        EnableGroupLink.call("group123", session_no_service, credentials)
      end
    end
  end
end
