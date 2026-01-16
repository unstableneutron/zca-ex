defmodule ZcaEx.Api.Endpoints.JoinGroupLinkTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.JoinGroupLink
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

  describe "validate_link/1" do
    test "returns :ok for non-empty string" do
      assert :ok == JoinGroupLink.validate_link("https://zalo.me/g/abcdef")
    end

    test "returns error for empty string" do
      assert {:error, %ZcaEx.Error{message: "link cannot be empty"}} =
               JoinGroupLink.validate_link("")
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "link cannot be empty"}} =
               JoinGroupLink.validate_link(nil)
    end
  end

  describe "build_params/2" do
    test "builds correct params" do
      params = JoinGroupLink.build_params("https://zalo.me/g/abcdef", "vi")

      assert params.link == "https://zalo.me/g/abcdef"
      assert params.clientLang == "vi"
    end

    test "uses provided language" do
      params = JoinGroupLink.build_params("https://zalo.me/g/abcdef", "en")

      assert params.link == "https://zalo.me/g/abcdef"
      assert params.clientLang == "en"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = JoinGroupLink.build_base_url(session)

      assert url =~ "https://groupchat.zalo.me/api/group/link/join"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = JoinGroupLink.build_url(session, encrypted)

      assert url =~ "https://groupchat.zalo.me/api/group/link/join"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "returns error when link is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "link cannot be empty"}} =
               JoinGroupLink.call("", session, credentials)
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        JoinGroupLink.call("https://zalo.me/g/abcdef", session_no_service, credentials)
      end
    end
  end
end
