defmodule ZcaEx.Api.Endpoints.GetPollDetailTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetPollDetail
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

  describe "validate_poll_id/1" do
    test "returns :ok for valid poll_id" do
      assert :ok == GetPollDetail.validate_poll_id(123)
    end

    test "returns :ok for large poll_id" do
      assert :ok == GetPollDetail.validate_poll_id(999_999_999)
    end

    test "returns error for zero" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               GetPollDetail.validate_poll_id(0)
    end

    test "returns error for negative integer" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               GetPollDetail.validate_poll_id(-1)
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "poll_id is required"}} =
               GetPollDetail.validate_poll_id(nil)
    end

    test "returns error for string" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               GetPollDetail.validate_poll_id("123")
    end

    test "returns error for float" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               GetPollDetail.validate_poll_id(123.5)
    end
  end

  describe "build_params/2" do
    test "builds correct params" do
      params = GetPollDetail.build_params(12345, "test-imei")

      assert params.poll_id == 12345
      assert params.imei == "test-imei"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetPollDetail.build_base_url(session)

      assert url =~ "https://group.zalo.me/api/poll/detail"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/1" do
    test "builds URL without params", %{session: session} do
      url = GetPollDetail.build_url(session)

      assert url =~ "https://group.zalo.me/api/poll/detail"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{
        "poll_id" => 123,
        "creator" => "user456",
        "question" => "Test question?",
        "options" => [
          %{"option_id" => 1, "content" => "Option A", "vote_count" => 10, "voters" => ["u1", "u2"]},
          %{"option_id" => 2, "content" => "Option B", "vote_count" => 5, "voters" => ["u3"]}
        ],
        "created_time" => 1609459200000,
        "expired_time" => 0,
        "allow_multi_choices" => true,
        "allow_add_new_option" => false,
        "is_hide_vote_preview" => false,
        "is_anonymous" => true,
        "group_id" => "group789"
      }

      result = GetPollDetail.transform_response(data)

      assert result.poll_id == 123
      assert result.creator == "user456"
      assert result.question == "Test question?"
      assert result.group_id == "group789"
      assert result.allow_multi_choices == true
      assert result.is_anonymous == true
      assert length(result.options) == 2

      [opt1, opt2] = result.options
      assert opt1.option_id == 1
      assert opt1.content == "Option A"
      assert opt1.vote_count == 10
      assert opt1.voters == ["u1", "u2"]
      assert opt2.option_id == 2
      assert opt2.voters == ["u3"]
    end

    test "transforms response with atom keys" do
      data = %{
        poll_id: 456,
        creator: "user789",
        question: "Another question?",
        options: [%{option_id: 1, content: "X", vote_count: 0, voters: []}],
        group_id: "g123"
      }

      result = GetPollDetail.transform_response(data)

      assert result.poll_id == 456
      assert result.creator == "user789"
      assert result.group_id == "g123"
      assert length(result.options) == 1
    end

    test "handles missing options" do
      data = %{"poll_id" => 123}
      result = GetPollDetail.transform_response(data)

      assert result.options == []
    end

    test "handles nil options" do
      data = %{"poll_id" => 123, "options" => nil}
      result = GetPollDetail.transform_response(data)

      assert result.options == []
    end

    test "defaults vote_count to 0 and voters to empty list" do
      data = %{
        "poll_id" => 123,
        "options" => [%{"option_id" => 1, "content" => "A"}]
      }

      result = GetPollDetail.transform_response(data)
      [opt] = result.options

      assert opt.vote_count == 0
      assert opt.voters == []
    end
  end

  describe "call/3 validation" do
    test "returns error when poll_id is zero", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               GetPollDetail.call(session, credentials, 0)
    end

    test "returns error when poll_id is negative", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               GetPollDetail.call(session, credentials, -5)
    end

    test "returns error when poll_id is string", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               GetPollDetail.call(session, credentials, "123")
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        GetPollDetail.call(session_no_service, credentials, 123)
      end
    end
  end
end
