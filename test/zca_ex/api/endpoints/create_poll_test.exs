defmodule ZcaEx.Api.Endpoints.CreatePollTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.CreatePoll
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

  describe "validate_group_id/1" do
    test "returns :ok for valid group_id" do
      assert :ok == CreatePoll.validate_group_id("group123")
    end

    test "returns error for empty string" do
      assert {:error, %ZcaEx.Error{message: "group_id is required"}} =
               CreatePoll.validate_group_id("")
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "group_id is required"}} =
               CreatePoll.validate_group_id(nil)
    end

    test "returns error for non-string" do
      assert {:error, %ZcaEx.Error{message: "group_id must be a non-empty string"}} =
               CreatePoll.validate_group_id(123)
    end
  end

  describe "validate_question/1" do
    test "returns :ok for valid question" do
      assert :ok == CreatePoll.validate_question("What is your favorite color?")
    end

    test "returns error for empty string" do
      assert {:error, %ZcaEx.Error{message: "question is required"}} =
               CreatePoll.validate_question("")
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "question is required"}} =
               CreatePoll.validate_question(nil)
    end

    test "returns error for non-string" do
      assert {:error, %ZcaEx.Error{message: "question must be a non-empty string"}} =
               CreatePoll.validate_question(123)
    end
  end

  describe "validate_options/1" do
    test "returns :ok for valid options list with 2+ items" do
      assert :ok == CreatePoll.validate_options(["Option A", "Option B"])
    end

    test "returns :ok for options list with many items" do
      assert :ok == CreatePoll.validate_options(["A", "B", "C", "D", "E"])
    end

    test "returns error for list with single option" do
      assert {:error, %ZcaEx.Error{message: "Poll must have at least 2 options"}} =
               CreatePoll.validate_options(["Only one"])
    end

    test "returns error for empty list" do
      assert {:error, %ZcaEx.Error{message: "Poll must have at least 2 options"}} =
               CreatePoll.validate_options([])
    end

    test "returns error for non-list" do
      assert {:error, %ZcaEx.Error{message: "options must be a list"}} =
               CreatePoll.validate_options("not a list")
    end
  end

  describe "build_params/5" do
    test "builds correct default params" do
      params = CreatePoll.build_params("group123", "Question?", ["A", "B"], "test-imei")

      assert params.group_id == "group123"
      assert params.question == "Question?"
      assert params.options == ["A", "B"]
      assert params.imei == "test-imei"
      assert params.expired_time == 0
      assert params.pinAct == false
      assert params.allow_multi_choices == false
      assert params.allow_add_new_option == false
      assert params.is_hide_vote_preview == false
      assert params.is_anonymous == false
      assert params.poll_type == 0
      assert params.src == 1
    end

    test "builds params with all options enabled" do
      opts = [
        expired_time: 3600000,
        allow_multi_choices: true,
        allow_add_new_option: true,
        hide_vote_preview: true,
        is_anonymous: true
      ]

      params = CreatePoll.build_params("group123", "Q?", ["A", "B"], "imei", opts)

      assert params.expired_time == 3600000
      assert params.allow_multi_choices == true
      assert params.allow_add_new_option == true
      assert params.is_hide_vote_preview == true
      assert params.is_anonymous == true
    end

    test "coerces truthy values to boolean" do
      opts = [allow_multi_choices: "yes"]
      params = CreatePoll.build_params("group123", "Q?", ["A", "B"], "imei", opts)

      assert params.allow_multi_choices == true
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = CreatePoll.build_base_url(session)

      assert url =~ "https://group.zalo.me/api/poll/create"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/1" do
    test "builds URL without params", %{session: session} do
      url = CreatePoll.build_url(session)

      assert url =~ "https://group.zalo.me/api/poll/create"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{
        "poll_id" => 123,
        "creator" => "user456",
        "question" => "Test?",
        "options" => [
          %{"option_id" => 1, "content" => "A", "vote_count" => 5},
          %{"option_id" => 2, "content" => "B", "vote_count" => 3}
        ],
        "created_time" => 1000,
        "expired_time" => 0,
        "allow_multi_choices" => false,
        "allow_add_new_option" => true,
        "is_hide_vote_preview" => false,
        "is_anonymous" => false
      }

      result = CreatePoll.transform_response(data)

      assert result.poll_id == 123
      assert result.creator == "user456"
      assert result.question == "Test?"
      assert length(result.options) == 2
      assert hd(result.options).option_id == 1
      assert hd(result.options).content == "A"
      assert hd(result.options).vote_count == 5
    end

    test "transforms response with atom keys" do
      data = %{
        poll_id: 456,
        creator: "user789",
        question: "Another?",
        options: []
      }

      result = CreatePoll.transform_response(data)

      assert result.poll_id == 456
      assert result.creator == "user789"
    end

    test "handles missing options" do
      data = %{"poll_id" => 123}
      result = CreatePoll.transform_response(data)

      assert result.options == []
    end
  end

  describe "call/4 validation" do
    test "returns error when group_id is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "group_id is required"}} =
               CreatePoll.call(session, credentials, "", question: "Q?", options: ["A", "B"])
    end

    test "returns error when question is missing", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "question is required"}} =
               CreatePoll.call(session, credentials, "group123", options: ["A", "B"])
    end

    test "returns error when options has less than 2 items", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Poll must have at least 2 options"}} =
               CreatePoll.call(session, credentials, "group123", question: "Q?", options: ["A"])
    end

    test "returns error when options is not provided", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "Poll must have at least 2 options"}} =
               CreatePoll.call(session, credentials, "group123", question: "Q?")
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        CreatePoll.call(session_no_service, credentials, "group123",
          question: "Q?",
          options: ["A", "B"]
        )
      end
    end
  end
end
