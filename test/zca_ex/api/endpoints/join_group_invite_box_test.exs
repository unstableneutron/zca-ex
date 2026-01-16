defmodule ZcaEx.Api.Endpoints.JoinGroupInviteBoxTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.JoinGroupInviteBox
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
      assert :ok == JoinGroupInviteBox.validate_group_id("group123")
    end

    test "returns error for nil group_id" do
      assert {:error, %ZcaEx.Error{message: "Group ID is required"}} =
               JoinGroupInviteBox.validate_group_id(nil)
    end

    test "returns error for empty string" do
      assert {:error, %ZcaEx.Error{message: "Group ID cannot be empty"}} =
               JoinGroupInviteBox.validate_group_id("")
    end

    test "returns error for non-string" do
      assert {:error, %ZcaEx.Error{message: "Group ID must be a string"}} =
               JoinGroupInviteBox.validate_group_id(123)
    end
  end

  describe "build_params/2" do
    test "builds correct params" do
      params = JoinGroupInviteBox.build_params("group123", "vi")

      assert params.grid == "group123"
      assert params.lang == "vi"
    end

    test "uses grid not grId for group ID" do
      params = JoinGroupInviteBox.build_params("group123", "en")

      assert Map.has_key?(params, :grid)
      refute Map.has_key?(params, :grId)
    end

    test "uses lang not language" do
      params = JoinGroupInviteBox.build_params("group123", "en")

      assert Map.has_key?(params, :lang)
      refute Map.has_key?(params, :language)
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = JoinGroupInviteBox.build_base_url(session)

      assert url =~ "https://groupchat.zalo.me/api/group/inv-box/join"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = JoinGroupInviteBox.build_url(session, encrypted)

      assert url =~ "https://groupchat.zalo.me/api/group/inv-box/join"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "returns error when group_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Group ID is required"}} =
               JoinGroupInviteBox.call(nil, session, credentials)
    end

    test "returns error when group_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Group ID cannot be empty"}} =
               JoinGroupInviteBox.call("", session, credentials)
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        JoinGroupInviteBox.call("group123", session_no_service, credentials)
      end
    end
  end
end
