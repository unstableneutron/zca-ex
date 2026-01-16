defmodule ZcaEx.Api.Endpoints.GetGroupInviteBoxListTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetGroupInviteBoxList
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

  describe "build_params/1" do
    test "builds correct params with defaults" do
      params = GetGroupInviteBoxList.build_params()

      assert params.mpage == 1
      assert params.page == 0
      assert params.invPerPage == 12
      assert params.mcount == 10
      assert params.lastGroupId == nil
      assert params.avatar_size == 120
      assert params.member_avatar_size == 120
    end

    test "builds params with custom options" do
      params = GetGroupInviteBoxList.build_params(mpage: 2, page: 1, invPerPage: 24, mcount: 20)

      assert params.mpage == 2
      assert params.page == 1
      assert params.invPerPage == 24
      assert params.mcount == 20
      assert params.lastGroupId == nil
      assert params.avatar_size == 120
      assert params.member_avatar_size == 120
    end

    test "always sets fixed values for avatar sizes and lastGroupId" do
      params = GetGroupInviteBoxList.build_params(avatar_size: 200, lastGroupId: "ignored")

      assert params.avatar_size == 120
      assert params.member_avatar_size == 120
      assert params.lastGroupId == nil
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetGroupInviteBoxList.build_base_url(session)

      assert url =~ "https://groupchat.zalo.me/api/group/inv-box/list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetGroupInviteBoxList.build_url(session, encrypted)

      assert url =~ "https://groupchat.zalo.me/api/group/inv-box/list"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3" do
    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetGroupInviteBoxList.call([], session_no_service, credentials)
      end
    end
  end
end
