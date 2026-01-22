defmodule ZcaEx.Api.Endpoints.DeleteGroupInviteBoxTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.DeleteGroupInviteBox
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

  describe "normalize_group_ids/1" do
    test "converts single string to list" do
      assert ["group123"] == DeleteGroupInviteBox.normalize_group_ids("group123")
    end

    test "keeps list as is" do
      assert ["g1", "g2"] == DeleteGroupInviteBox.normalize_group_ids(["g1", "g2"])
    end

    test "returns empty list for nil" do
      assert [] == DeleteGroupInviteBox.normalize_group_ids(nil)
    end

    test "returns empty list for invalid input" do
      assert [] == DeleteGroupInviteBox.normalize_group_ids(123)
      assert [] == DeleteGroupInviteBox.normalize_group_ids(%{})
    end
  end

  describe "validate_group_ids/1" do
    test "returns :ok for non-empty list" do
      assert :ok == DeleteGroupInviteBox.validate_group_ids(["group123"])
    end

    test "returns error for empty list" do
      assert {:error, %ZcaEx.Error{message: "Group IDs cannot be empty", code: :invalid_input}} =
               DeleteGroupInviteBox.validate_group_ids([])
    end
  end

  describe "build_params/2" do
    test "builds correct params with single group id" do
      {:ok, params} = DeleteGroupInviteBox.build_params(["group123"])

      assert params.block == 0
      {:ok, decoded} = Jason.decode(params.invitations)
      assert decoded == [%{"grid" => "group123"}]
    end

    test "builds correct params with multiple group ids" do
      {:ok, params} = DeleteGroupInviteBox.build_params(["g1", "g2", "g3"])

      {:ok, decoded} = Jason.decode(params.invitations)
      assert decoded == [%{"grid" => "g1"}, %{"grid" => "g2"}, %{"grid" => "g3"}]
    end

    test "sets block to 1 when block option is true" do
      {:ok, params} = DeleteGroupInviteBox.build_params(["group123"], block: true)

      assert params.block == 1
    end

    test "sets block to 0 when block option is false" do
      {:ok, params} = DeleteGroupInviteBox.build_params(["group123"], block: false)

      assert params.block == 0
    end

    test "invitations is a JSON string" do
      {:ok, params} = DeleteGroupInviteBox.build_params(["group123"])

      assert is_binary(params.invitations)
      assert {:ok, _} = Jason.decode(params.invitations)
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = DeleteGroupInviteBox.build_base_url(session)

      assert url =~ "https://groupchat.zalo.me/api/group/inv-box/mdel-inv"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = DeleteGroupInviteBox.build_url(session, encrypted)

      assert url =~ "https://groupchat.zalo.me/api/group/inv-box/mdel-inv"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/4 validation" do
    test "returns error when group_ids is empty list", %{
      session: session,
      credentials: credentials
    } do
      assert {:error, %ZcaEx.Error{message: "Group IDs cannot be empty", code: :invalid_input}} =
               DeleteGroupInviteBox.call([], [], session, credentials)
    end

    test "returns error when group_ids is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Group IDs cannot be empty", code: :invalid_input}} =
               DeleteGroupInviteBox.call(nil, [], session, credentials)
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        DeleteGroupInviteBox.call("group123", [], session_no_service, credentials)
      end
    end
  end
end
