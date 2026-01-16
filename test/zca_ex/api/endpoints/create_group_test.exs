defmodule ZcaEx.Api.Endpoints.CreateGroupTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.CreateGroup
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

  describe "validate_members/1" do
    test "returns :ok for non-empty list" do
      assert :ok == CreateGroup.validate_members(["user1", "user2"])
    end

    test "returns :ok for single member list" do
      assert :ok == CreateGroup.validate_members(["user1"])
    end

    test "returns error for empty list" do
      assert {:error, %ZcaEx.Error{message: "Group must have at least one member"}} =
               CreateGroup.validate_members([])
    end

    test "returns error for non-list" do
      assert {:error, %ZcaEx.Error{message: "Members must be a list"}} =
               CreateGroup.validate_members("not a list")
    end
  end

  describe "build_params/4" do
    test "builds correct default params without name" do
      params = CreateGroup.build_params("test-imei", ["user1", "user2"])

      assert is_integer(params.clientId)
      assert params.gname == to_string(params.clientId)
      assert params.gdesc == nil
      assert params.members == ["user1", "user2"]
      assert params.membersTypes == [-1, -1]
      assert params.nameChanged == 0
      assert params.createLink == 1
      assert params.clientLang == "vi"
      assert params.imei == "test-imei"
      assert params.zsource == 601
    end

    test "builds params with custom name" do
      params = CreateGroup.build_params("test-imei", ["user1"], "My Group", "vi")

      assert params.gname == "My Group"
      assert params.nameChanged == 1
    end

    test "ignores empty name string" do
      params = CreateGroup.build_params("test-imei", ["user1"], "", "vi")

      assert params.gname == to_string(params.clientId)
      assert params.nameChanged == 0
    end

    test "uses custom language" do
      params = CreateGroup.build_params("test-imei", ["user1"], nil, "en")

      assert params.clientLang == "en"
    end

    test "membersTypes matches members count" do
      members = ["u1", "u2", "u3", "u4", "u5"]
      params = CreateGroup.build_params("test-imei", members)

      assert length(params.membersTypes) == length(members)
      assert Enum.all?(params.membersTypes, &(&1 == -1))
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = CreateGroup.build_base_url(session)

      assert url =~ "https://group.zalo.me/api/group/create/v2"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = CreateGroup.build_url(session, encrypted)

      assert url =~ "https://group.zalo.me/api/group/create/v2"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "returns error when members is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Group must have at least one member"}} =
               CreateGroup.call(session, credentials, members: [])
    end

    test "returns error when members not provided", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Group must have at least one member"}} =
               CreateGroup.call(session, credentials)
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        CreateGroup.call(session_no_service, credentials, members: ["user1"])
      end
    end
  end
end
