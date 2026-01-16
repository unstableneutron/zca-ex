defmodule ZcaEx.Api.Endpoints.GetGroupInfoTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetGroupInfo
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

  describe "build_grid_ver_map/1" do
    test "builds map with group IDs as keys and 0 as version" do
      group_ids = ["group1", "group2", "group3"]
      result = GetGroupInfo.build_grid_ver_map(group_ids)

      assert result == %{
               "group1" => 0,
               "group2" => 0,
               "group3" => 0
             }
    end

    test "handles single group ID" do
      result = GetGroupInfo.build_grid_ver_map(["single_group"])
      assert result == %{"single_group" => 0}
    end

    test "handles empty list" do
      assert GetGroupInfo.build_grid_ver_map([]) == %{}
    end
  end

  describe "build_params/1" do
    test "builds params with JSON-encoded gridVerMap" do
      group_ids = ["group1", "group2"]
      params = GetGroupInfo.build_params(group_ids)

      assert Map.has_key?(params, :gridVerMap)
      assert is_binary(params.gridVerMap)

      decoded = Jason.decode!(params.gridVerMap)
      assert decoded == %{"group1" => 0, "group2" => 0}
    end
  end

  describe "build_url/1" do
    test "builds correct URL with session params", %{session: session} do
      url = GetGroupInfo.build_url(session)

      assert url =~ "https://group.zalo.me/api/group/getmg-v2"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 input handling" do
    test "handles single group ID string", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetGroupInfo.call("single_group", session_no_service, credentials)
      end
    end

    test "handles list of group IDs", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetGroupInfo.call(["group1", "group2"], session_no_service, credentials)
      end
    end
  end
end
