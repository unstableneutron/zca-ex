defmodule ZcaEx.Api.Endpoints.AddReactionTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZcaEx.Api.Endpoints.AddReaction
  alias ZcaEx.HTTP.{AccountClientMock, Response}
  alias ZcaEx.Test.Fixtures
  alias ZcaEx.Model.Enums

  setup :verify_on_exit!

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/4 with standard reaction" do
    test "sends reaction to user thread", %{session: session, credentials: credentials} do
      response_data = %{"msgIds" => [123, 456]}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, body, _user_agent, _headers ->
        assert url =~ "/api/message/reaction"
        assert body =~ "params="
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      target = %{
        msg_id: "1000",
        cli_msg_id: "2000",
        thread_id: "user123",
        thread_type: :user
      }

      result = AddReaction.call(:heart, target, session, credentials)

      assert {:ok, %{msg_ids: [123, 456]}} = result
    end

    test "sends reaction to group thread", %{session: session, credentials: credentials} do
      response_data = %{"msgIds" => [789]}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, url, _body, _user_agent, _headers ->
        assert url =~ "/api/group/reaction"
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      target = %{
        msg_id: "3000",
        cli_msg_id: "4000",
        thread_id: "group456",
        thread_type: :group
      }

      result = AddReaction.call(:like, target, session, credentials)

      assert {:ok, %{msg_ids: [789]}} = result
    end

    test "handles various reaction types", %{session: session, credentials: credentials} do
      response_data = %{"msgIds" => [1]}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      target = %{msg_id: "1", cli_msg_id: "1", thread_id: "user1", thread_type: :user}

      for reaction <- [:haha, :wow, :cry, :angry, :kiss] do
        expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
          {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
        end)

        result = AddReaction.call(reaction, target, session, credentials)
        assert {:ok, _} = result

        {r_type, _source} = Enums.reaction_type(reaction)
        assert is_integer(r_type)
      end
    end
  end

  describe "call/4 with custom reaction" do
    test "sends custom reaction", %{session: session, credentials: credentials} do
      response_data = %{"msgIds" => [999]}
      response = Fixtures.build_success_response(response_data, session.secret_key)

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      custom = %{r_type: 100, source: 6, icon: "custom-icon"}

      target = %{
        msg_id: "5000",
        cli_msg_id: "6000",
        thread_id: "user789",
        thread_type: :user
      }

      result = AddReaction.call(custom, target, session, credentials)

      assert {:ok, %{msg_ids: [999]}} = result
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      response = Fixtures.build_error_response(-1, "Invalid message")

      expect(AccountClientMock, :post, fn _account_id, _url, _body, _user_agent, _headers ->
        {:ok, %Response{status: response.status, body: response.body, headers: response.headers}}
      end)

      target = %{msg_id: "1", cli_msg_id: "1", thread_id: "user1", thread_type: :user}

      result = AddReaction.call(:heart, target, session, credentials)

      assert {:error, error} = result
      assert error.message == "Invalid message"
    end
  end
end
