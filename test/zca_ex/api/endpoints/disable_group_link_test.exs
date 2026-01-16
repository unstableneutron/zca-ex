defmodule ZcaEx.Api.Endpoints.DisableGroupLinkTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.DisableGroupLink
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

  describe "validate_group_id/1" do
    test "returns :ok for non-empty string" do
      assert :ok == DisableGroupLink.validate_group_id("group123")
    end

    test "returns error for empty string" do
      assert {:error, %ZcaEx.Error{message: "group_id cannot be empty", code: :invalid_input}} =
               DisableGroupLink.validate_group_id("")
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "group_id cannot be empty", code: :invalid_input}} =
               DisableGroupLink.validate_group_id(nil)
    end
  end

  describe "build_params/1" do
    test "builds correct params" do
      params = DisableGroupLink.build_params("group123")

      assert params.grid == "group123"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = DisableGroupLink.build_base_url(session)

      assert url =~ "https://groupchat.zalo.me/api/group/link/disable"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = DisableGroupLink.build_url(session, encrypted)

      assert url =~ "https://groupchat.zalo.me/api/group/link/disable"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "returns error when group_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "group_id cannot be empty", code: :invalid_input}} =
               DisableGroupLink.call("", session, credentials)
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        DisableGroupLink.call("group123", session_no_service, credentials)
      end
    end
  end
end
