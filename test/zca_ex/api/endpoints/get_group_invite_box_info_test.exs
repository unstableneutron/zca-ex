defmodule ZcaEx.Api.Endpoints.GetGroupInviteBoxInfoTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetGroupInviteBoxInfo
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
    test "returns :ok for valid group_id" do
      assert :ok == GetGroupInviteBoxInfo.validate_group_id("group123")
    end

    test "returns error for nil group_id" do
      assert {:error, %ZcaEx.Error{message: "Group ID is required"}} =
               GetGroupInviteBoxInfo.validate_group_id(nil)
    end

    test "returns error for empty string" do
      assert {:error, %ZcaEx.Error{message: "Group ID cannot be empty"}} =
               GetGroupInviteBoxInfo.validate_group_id("")
    end

    test "returns error for non-string" do
      assert {:error, %ZcaEx.Error{message: "Group ID must be a string"}} =
               GetGroupInviteBoxInfo.validate_group_id(123)
    end
  end

  describe "build_params/2" do
    test "builds correct params with defaults" do
      params = GetGroupInviteBoxInfo.build_params("group123")

      assert params.grId == "group123"
      assert params.mcount == 10
      assert params.mpage == 1
    end

    test "builds params with custom options" do
      params = GetGroupInviteBoxInfo.build_params("group123", mcount: 20, mpage: 3)

      assert params.grId == "group123"
      assert params.mcount == 20
      assert params.mpage == 3
    end

    test "uses grId not grid for group ID" do
      params = GetGroupInviteBoxInfo.build_params("group123")

      assert Map.has_key?(params, :grId)
      refute Map.has_key?(params, :grid)
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetGroupInviteBoxInfo.build_base_url(session)

      assert url =~ "https://groupchat.zalo.me/api/group/inv-box/inv-info"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetGroupInviteBoxInfo.build_url(session, encrypted)

      assert url =~ "https://groupchat.zalo.me/api/group/inv-box/inv-info"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/4 validation" do
    test "returns error when group_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Group ID is required"}} =
               GetGroupInviteBoxInfo.call(nil, [], session, credentials)
    end

    test "returns error when group_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Group ID cannot be empty"}} =
               GetGroupInviteBoxInfo.call("", [], session, credentials)
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetGroupInviteBoxInfo.call("group123", [], session_no_service, credentials)
      end
    end
  end
end
