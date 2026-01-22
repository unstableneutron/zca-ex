defmodule ZcaEx.Api.Endpoints.AddPollOptionsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.AddPollOptions
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
    test "returns :ok for valid positive integer poll_id" do
      assert :ok == AddPollOptions.validate_poll_id(123)
    end

    test "returns error for nil poll_id" do
      assert {:error, %ZcaEx.Error{message: "poll_id is required"}} =
               AddPollOptions.validate_poll_id(nil)
    end

    test "returns error for zero poll_id" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               AddPollOptions.validate_poll_id(0)
    end

    test "returns error for negative poll_id" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               AddPollOptions.validate_poll_id(-1)
    end

    test "returns error for non-integer poll_id" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               AddPollOptions.validate_poll_id("123")
    end
  end

  describe "validate_new_options/1" do
    test "returns :ok for non-empty list" do
      assert :ok == AddPollOptions.validate_new_options([%{voted: true, content: "New option"}])
    end

    test "returns error for empty list" do
      assert {:error, %ZcaEx.Error{message: "options cannot be empty"}} =
               AddPollOptions.validate_new_options([])
    end

    test "returns error for non-list" do
      assert {:error, %ZcaEx.Error{message: "options must be a list"}} =
               AddPollOptions.validate_new_options("not a list")
    end
  end

  describe "build_params/2" do
    test "builds correct params with options" do
      new_options = [%{voted: true, content: "Option 1"}, %{voted: false, content: "Option 2"}]
      {:ok, params} = AddPollOptions.build_params(123, options: new_options)

      assert params.poll_id == 123
      assert params.voted_option_ids == []

      decoded = Jason.decode!(params.new_options)
      assert length(decoded) == 2
    end

    test "builds params with voted_option_ids" do
      new_options = [%{voted: true, content: "New option"}]

      {:ok, params} =
        AddPollOptions.build_params(123, options: new_options, voted_option_ids: [1, 2])

      assert params.poll_id == 123
      assert params.voted_option_ids == [1, 2]
    end

    test "builds params with default values" do
      {:ok, params} = AddPollOptions.build_params(123, [])

      assert params.poll_id == 123
      assert params.new_options == "[]"
      assert params.voted_option_ids == []
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = AddPollOptions.build_base_url(session)

      assert url =~ "https://group.zalo.me/api/poll/option/add"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = AddPollOptions.build_url(session, encrypted)

      assert url =~ "https://group.zalo.me/api/poll/option/add"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/4 validation" do
    test "returns error when poll_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "poll_id is required"}} =
               AddPollOptions.call(nil, session, credentials,
                 options: [%{voted: true, content: "New"}]
               )
    end

    test "returns error when poll_id is zero", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               AddPollOptions.call(0, session, credentials,
                 options: [%{voted: true, content: "New"}]
               )
    end

    test "returns error when options is empty", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "options cannot be empty"}} =
               AddPollOptions.call(123, session, credentials, options: [])
    end
  end

  describe "transform_response/1" do
    test "transforms options correctly" do
      data = %{
        "options" => [
          %{
            "option_id" => 1,
            "content" => "Option A",
            "votes" => 5,
            "voted" => true,
            "voters" => ["u1"]
          },
          %{
            "option_id" => 2,
            "content" => "Option B",
            "votes" => 3,
            "voted" => false,
            "voters" => []
          }
        ]
      }

      result = AddPollOptions.transform_response(data)

      assert length(result.options) == 2
      assert Enum.at(result.options, 0).option_id == 1
      assert Enum.at(result.options, 0).content == "Option A"
      assert Enum.at(result.options, 0).vote_count == 5
      assert Enum.at(result.options, 0).voted == true
    end

    test "handles empty options" do
      data = %{}

      result = AddPollOptions.transform_response(data)

      assert result.options == []
    end
  end
end
