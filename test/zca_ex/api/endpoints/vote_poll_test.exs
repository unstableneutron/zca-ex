defmodule ZcaEx.Api.Endpoints.VotePollTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.VotePoll
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
      assert :ok == VotePoll.validate_poll_id(123)
    end

    test "returns :ok for large poll_id" do
      assert :ok == VotePoll.validate_poll_id(999_999_999)
    end

    test "returns error for zero" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               VotePoll.validate_poll_id(0)
    end

    test "returns error for negative integer" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               VotePoll.validate_poll_id(-1)
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "poll_id is required"}} =
               VotePoll.validate_poll_id(nil)
    end

    test "returns error for string" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               VotePoll.validate_poll_id("123")
    end
  end

  describe "validate_option_ids/1" do
    test "returns :ok for empty list (unvote)" do
      assert :ok == VotePoll.validate_option_ids([])
    end

    test "returns :ok for single option" do
      assert :ok == VotePoll.validate_option_ids([1])
    end

    test "returns :ok for multiple options" do
      assert :ok == VotePoll.validate_option_ids([1, 2, 3])
    end

    test "returns error for list with non-integers" do
      assert {:error, %ZcaEx.Error{message: "option_ids must be a list of integers"}} =
               VotePoll.validate_option_ids([1, "2", 3])
    end

    test "returns error for list with strings" do
      assert {:error, %ZcaEx.Error{message: "option_ids must be a list of integers"}} =
               VotePoll.validate_option_ids(["a", "b"])
    end

    test "returns error for non-list" do
      assert {:error, %ZcaEx.Error{message: "option_ids must be a list"}} =
               VotePoll.validate_option_ids(123)
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "option_ids must be a list"}} =
               VotePoll.validate_option_ids(nil)
    end
  end

  describe "build_params/3" do
    test "builds correct params with options" do
      params = VotePoll.build_params(12345, [1, 2], "test-imei")

      assert params.poll_id == 12345
      assert params.option_ids == [1, 2]
      assert params.imei == "test-imei"
    end

    test "builds correct params for unvote (empty options)" do
      params = VotePoll.build_params(12345, [], "test-imei")

      assert params.poll_id == 12345
      assert params.option_ids == []
      assert params.imei == "test-imei"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = VotePoll.build_base_url(session)

      assert url =~ "https://group.zalo.me/api/poll/vote"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = VotePoll.build_url(session, encrypted)

      assert url =~ "https://group.zalo.me/api/poll/vote"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "transforms response with string keys" do
      data = %{
        "options" => [
          %{"option_id" => 1, "content" => "Option A", "vote_count" => 10, "voters" => ["u1", "u2"]},
          %{"option_id" => 2, "content" => "Option B", "vote_count" => 5, "voters" => ["u3"]}
        ]
      }

      result = VotePoll.transform_response(data)

      assert length(result.options) == 2
      [opt1, opt2] = result.options
      assert opt1.option_id == 1
      assert opt1.content == "Option A"
      assert opt1.vote_count == 10
      assert opt1.voters == ["u1", "u2"]
      assert opt2.option_id == 2
      assert opt2.vote_count == 5
    end

    test "transforms response with atom keys" do
      data = %{
        options: [%{option_id: 1, content: "X", vote_count: 3, voters: ["v1"]}]
      }

      result = VotePoll.transform_response(data)

      assert length(result.options) == 1
      [opt] = result.options
      assert opt.option_id == 1
      assert opt.voters == ["v1"]
    end

    test "handles missing options" do
      data = %{}
      result = VotePoll.transform_response(data)

      assert result.options == []
    end

    test "handles nil options" do
      data = %{"options" => nil}
      result = VotePoll.transform_response(data)

      assert result.options == []
    end

    test "defaults vote_count to 0 and voters to empty list" do
      data = %{
        "options" => [%{"option_id" => 1, "content" => "A"}]
      }

      result = VotePoll.transform_response(data)
      [opt] = result.options

      assert opt.vote_count == 0
      assert opt.voters == []
    end
  end

  describe "call/4 validation" do
    test "returns error when poll_id is zero", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               VotePoll.call(session, credentials, 0, [1])
    end

    test "returns error when poll_id is negative", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               VotePoll.call(session, credentials, -5, [1])
    end

    test "returns error when option_ids contains non-integers", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "option_ids must be a list of integers"}} =
               VotePoll.call(session, credentials, 123, [1, "2"])
    end

    test "returns error when option_ids is not a list", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "option_ids must be a list"}} =
               VotePoll.call(session, credentials, 123, 1)
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        VotePoll.call(session_no_service, credentials, 123, [1])
      end
    end
  end
end
