defmodule ZcaEx.Api.Endpoints.SendReportTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SendReport
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "profile" => ["https://profile.zalo.me"]
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

  describe "validate_thread_id/1" do
    test "returns :ok for valid thread_id" do
      assert :ok == SendReport.validate_thread_id("user123")
    end

    test "returns error for empty string" do
      assert {:error, error} = SendReport.validate_thread_id("")
      assert error.code == :invalid_input
    end

    test "returns error for nil" do
      assert {:error, error} = SendReport.validate_thread_id(nil)
      assert error.code == :invalid_input
    end

    test "returns error for non-string" do
      assert {:error, error} = SendReport.validate_thread_id(123)
      assert error.code == :invalid_input
    end
  end

  describe "validate_thread_type/1" do
    test "returns :ok for :user" do
      assert :ok == SendReport.validate_thread_type(:user)
    end

    test "returns :ok for :group" do
      assert :ok == SendReport.validate_thread_type(:group)
    end

    test "returns error for invalid type" do
      assert {:error, error} = SendReport.validate_thread_type(:invalid)
      assert error.message =~ ":user or :group"
      assert error.code == :invalid_input

      assert {:error, _} = SendReport.validate_thread_type("user")
      assert {:error, _} = SendReport.validate_thread_type(nil)
    end
  end

  describe "validate_reason/1" do
    test "returns :ok for valid reasons" do
      assert :ok == SendReport.validate_reason(:sensitive)
      assert :ok == SendReport.validate_reason(:annoy)
      assert :ok == SendReport.validate_reason(:fraud)
      assert :ok == SendReport.validate_reason(:other)
    end

    test "returns error for invalid reason" do
      assert {:error, error} = SendReport.validate_reason(:invalid)
      assert error.code == :invalid_input

      assert {:error, _} = SendReport.validate_reason("sensitive")
      assert {:error, _} = SendReport.validate_reason(1)
    end
  end

  describe "validate_content/2" do
    test "returns :ok for :other with valid content" do
      assert :ok == SendReport.validate_content(:other, "This is my report")
    end

    test "returns error for :other with nil content" do
      assert {:error, error} = SendReport.validate_content(:other, nil)
      assert error.message =~ "content is required"
      assert error.code == :invalid_input
    end

    test "returns error for :other with empty content" do
      assert {:error, error} = SendReport.validate_content(:other, "")
      assert error.code == :invalid_input
    end

    test "returns :ok for non-:other reasons regardless of content" do
      assert :ok == SendReport.validate_content(:sensitive, nil)
      assert :ok == SendReport.validate_content(:annoy, "")
      assert :ok == SendReport.validate_content(:fraud, "some content")
    end
  end

  describe "reason_to_value/1" do
    test "converts reasons to correct integer values" do
      assert SendReport.reason_to_value(:sensitive) == 1
      assert SendReport.reason_to_value(:annoy) == 2
      assert SendReport.reason_to_value(:fraud) == 3
      assert SendReport.reason_to_value(:other) == 0
    end
  end

  describe "build_params/5 for :user" do
    test "builds correct params for :user without content" do
      params = SendReport.build_params("user123", :user, :sensitive, nil, "test-imei")

      assert params.idTo == "user123"
      assert params.objId == "person.profile"
      assert params.reason == "1"
      refute Map.has_key?(params, :content)
      refute Map.has_key?(params, :imei)
    end

    test "builds correct params for :user with :other reason" do
      params = SendReport.build_params("user123", :user, :other, "My report content", "test-imei")

      assert params.idTo == "user123"
      assert params.objId == "person.profile"
      assert params.reason == "0"
      assert params.content == "My report content"
      refute Map.has_key?(params, :imei)
    end
  end

  describe "build_params/5 for :group" do
    test "builds correct params for :group without content" do
      params = SendReport.build_params("group456", :group, :fraud, nil, "test-imei")

      assert params.uidTo == "group456"
      assert params.type == 14
      assert params.reason == 3
      assert params.content == ""
      assert params.imei == "test-imei"
    end

    test "builds correct params for :group with :other reason" do
      params = SendReport.build_params("group456", :group, :other, "My group report", "test-imei")

      assert params.uidTo == "group456"
      assert params.type == 14
      assert params.reason == 0
      assert params.content == "My group report"
      assert params.imei == "test-imei"
    end
  end

  describe "build_url/3" do
    test "builds correct URL for :user", %{session: session} do
      url = SendReport.build_url("https://profile.zalo.me", :user, session)

      assert url =~ "https://profile.zalo.me/api/report/abuse-v2"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "builds correct URL for :group", %{session: session} do
      url = SendReport.build_url("https://profile.zalo.me", :group, session)

      assert url =~ "https://profile.zalo.me/api/social/profile/reportabuse"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_base_url/2" do
    test "builds correct base URL for :user", %{session: session} do
      assert {:ok, url} = SendReport.build_base_url(session, :user)

      assert url =~ "https://profile.zalo.me/api/report/abuse-v2"
      assert url =~ "zpw_ver=645"
    end

    test "builds correct base URL for :group", %{session: session} do
      assert {:ok, url} = SendReport.build_base_url(session, :group)

      assert url =~ "https://profile.zalo.me/api/social/profile/reportabuse"
      assert url =~ "zpw_ver=645"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"profile" => "https://profile2.zalo.me"}}
      assert {:ok, url} = SendReport.build_base_url(session, :user)

      assert url =~ "https://profile2.zalo.me/api/report/abuse-v2"
    end

    test "returns error when service URL not found", %{session: session} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert {:error, error} = SendReport.build_base_url(session_no_service, :user)
      assert error.message == "profile service URL not found"
      assert error.code == :service_not_found
    end
  end

  describe "call/6 validation" do
    test "returns error for empty thread_id", %{session: session, credentials: credentials} do
      assert {:error, error} = SendReport.call(session, credentials, "", :user, :sensitive)
      assert error.code == :invalid_input
    end

    test "returns error for invalid thread_type", %{session: session, credentials: credentials} do
      assert {:error, error} = SendReport.call(session, credentials, "user123", :invalid, :sensitive)
      assert error.message =~ ":user or :group"
    end

    test "returns error for invalid reason", %{session: session, credentials: credentials} do
      assert {:error, error} = SendReport.call(session, credentials, "user123", :user, :invalid)
      assert error.code == :invalid_input
    end

    test "returns error for :other without content", %{session: session, credentials: credentials} do
      assert {:error, error} = SendReport.call(session, credentials, "user123", :user, :other)
      assert error.message =~ "content is required"
    end

    test "returns error for :other with empty content", %{session: session, credentials: credentials} do
      assert {:error, error} = SendReport.call(session, credentials, "user123", :user, :other, "")
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert {:error, error} = SendReport.call(session_no_service, credentials, "user123", :user, :sensitive)
      assert error.message == "profile service URL not found"
      assert error.code == :service_not_found
    end
  end
end
