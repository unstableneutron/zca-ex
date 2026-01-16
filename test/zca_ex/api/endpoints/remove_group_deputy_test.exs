defmodule ZcaEx.Api.Endpoints.RemoveGroupDeputyTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.RemoveGroupDeputy
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

  describe "build_params/3" do
    test "builds correct params with single member_id" do
      params = RemoveGroupDeputy.build_params("group123", ["member456"], "test-imei")

      assert params.grid == "group123"
      assert params.members == ["member456"]
      assert params.imei == "test-imei"
    end

    test "builds correct params with list of member_ids" do
      member_ids = ["member1", "member2", "member3"]
      params = RemoveGroupDeputy.build_params("group123", member_ids, "test-imei")

      assert params.grid == "group123"
      assert params.members == ["member1", "member2", "member3"]
      assert params.imei == "test-imei"
    end
  end

  describe "normalize_member_ids/1" do
    test "converts single string to list" do
      assert RemoveGroupDeputy.normalize_member_ids("member123") == ["member123"]
    end

    test "keeps list as is" do
      members = ["member1", "member2"]
      assert RemoveGroupDeputy.normalize_member_ids(members) == members
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = RemoveGroupDeputy.build_base_url(session)

      assert url =~ "https://groupchat.zalo.me/api/group/admins/remove"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = RemoveGroupDeputy.build_url(session, encrypted)

      assert url =~ "https://groupchat.zalo.me/api/group/admins/remove"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/4 validation" do
    test "returns error for empty member_id list", %{session: session, credentials: credentials} do
      result = RemoveGroupDeputy.call("group123", [], session, credentials)

      assert {:error, error} = result
      assert error.message == "member_id cannot be empty"
    end

    test "raises for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        RemoveGroupDeputy.call("group123", "member456", session_no_service, credentials)
      end
    end
  end
end
