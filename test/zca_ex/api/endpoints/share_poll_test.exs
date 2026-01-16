defmodule ZcaEx.Api.Endpoints.SharePollTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SharePoll
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
      assert :ok == SharePoll.validate_poll_id(123)
    end

    test "returns error for zero poll_id" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               SharePoll.validate_poll_id(0)
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "poll_id is required"}} =
               SharePoll.validate_poll_id(nil)
    end

    test "returns error for negative poll_id" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               SharePoll.validate_poll_id(-1)
    end

    test "returns error for non-integer" do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               SharePoll.validate_poll_id("123")
    end
  end

  describe "build_params/2" do
    test "builds correct params" do
      params = SharePoll.build_params(123, "test-imei")

      assert params.poll_id == 123
      assert params.imei == "test-imei"
    end
  end

  describe "build_url/1" do
    test "builds correct URL", %{session: session} do
      url = SharePoll.build_url(session)

      assert url =~ "https://group.zalo.me/api/poll/share"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "returns error when poll_id is zero", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               SharePoll.call(session, credentials, 0)
    end

    test "returns error when poll_id is nil", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "poll_id is required"}} =
               SharePoll.call(session, credentials, nil)
    end

    test "returns error when poll_id is negative", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "poll_id must be a positive integer"}} =
               SharePoll.call(session, credentials, -5)
    end
  end
end
