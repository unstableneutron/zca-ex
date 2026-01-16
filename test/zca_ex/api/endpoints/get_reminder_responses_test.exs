defmodule ZcaEx.Api.Endpoints.GetReminderResponsesTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetReminderResponses
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group_board" => ["https://board.zalo.me"]
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
    test "builds correct params with only eventId" do
      params = GetReminderResponses.build_params("reminder_123")

      assert params == %{eventId: "reminder_123"}
    end

    test "does not include imei param" do
      params = GetReminderResponses.build_params("reminder_456")

      refute Map.has_key?(params, :imei)
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetReminderResponses.build_base_url(session)

      assert url =~ "https://board.zalo.me/api/board/topic/listResponseEvent"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetReminderResponses.build_url(session, encrypted)

      assert url =~ "https://board.zalo.me/api/board/topic/listResponseEvent"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{
        "rejectMember" => ["user1", "user2"],
        "acceptMember" => ["user3", "user4", "user5"]
      }

      result = GetReminderResponses.transform_response(data)

      assert result == %{
               reject_members: ["user1", "user2"],
               accept_members: ["user3", "user4", "user5"]
             }
    end

    test "transforms response with atom keys" do
      data = %{
        rejectMember: ["user1"],
        acceptMember: ["user2", "user3"]
      }

      result = GetReminderResponses.transform_response(data)

      assert result == %{
               reject_members: ["user1"],
               accept_members: ["user2", "user3"]
             }
    end

    test "handles missing keys with empty lists" do
      data = %{}

      result = GetReminderResponses.transform_response(data)

      assert result == %{
               reject_members: [],
               accept_members: []
             }
    end

    test "handles nil values with empty lists" do
      data = %{"rejectMember" => nil, "acceptMember" => nil}

      result = GetReminderResponses.transform_response(data)

      assert result == %{
               reject_members: [],
               accept_members: []
             }
    end

    test "handles empty member lists" do
      data = %{"rejectMember" => [], "acceptMember" => []}

      result = GetReminderResponses.transform_response(data)

      assert result == %{
               reject_members: [],
               accept_members: []
             }
    end
  end

  describe "call/3 validation" do
    test "raises when group_board service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      assert_raise RuntimeError, ~r/Service URL not found for group_board/, fn ->
        GetReminderResponses.call("reminder_123", session_no_service, credentials)
      end
    end
  end
end
