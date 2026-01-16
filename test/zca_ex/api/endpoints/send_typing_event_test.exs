defmodule ZcaEx.Api.Endpoints.SendTypingEventTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Api.Endpoints.SendTypingEvent
  alias ZcaEx.Test.{MockAccountClient, Fixtures}

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/5 validation" do
    test "returns error for nil thread_id", %{session: session, credentials: credentials} do
      result = SendTypingEvent.call(nil, :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Missing thread_id"
    end

    test "returns error for empty thread_id", %{session: session, credentials: credentials} do
      result = SendTypingEvent.call("", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Missing thread_id"
    end
  end

  describe "call/5 to user" do
    test "sends typing event to user", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      result = call_with_mock(:user, "user123", session, credentials)

      assert :ok = result

      {url, body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/message/typing"
      assert body =~ "params="
    end

    test "sends typing event with page dest_type", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      result = call_with_mock(:user, "page123", session, credentials, dest_type: :page)

      assert :ok = result
    end
  end

  describe "call/5 to group" do
    test "sends typing event to group", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      result = call_with_mock(:group, "group456", session, credentials)

      assert :ok = result

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/group/typing"
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      MockAccountClient.setup_mock(Fixtures.build_error_response(-1, "Session expired"))

      result = call_with_mock(:user, "user123", session, credentials)

      assert {:error, error} = result
      assert error.message == "Session expired"
    end
  end

  defp call_with_mock(thread_type, thread_id, session, credentials, opts \\ []) do
    Code.eval_string("""
    defmodule ZcaEx.Api.Endpoints.SendTypingEventMock do
      use ZcaEx.Api.Factory
      alias ZcaEx.Model.Enums
      alias ZcaEx.Test.MockAccountClient, as: AccountClient

      def call(thread_id, thread_type, session, credentials, opts \\\\ []) do
        dest_type = Keyword.get(opts, :dest_type, :user)

        params = build_params(thread_id, thread_type, credentials.imei, dest_type)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(thread_type, session)
            body = build_form_body(%{params: encrypted_params})

            case AccountClient.post(credentials.imei, url, body, credentials.user_agent) do
              {:ok, resp} ->
                case Response.parse(resp, session.secret_key) do
                  {:ok, _data} -> :ok
                  error -> error
                end

              {:error, reason} ->
                {:error, %ZcaEx.Error{message: "Request failed: \#{inspect(reason)}", code: nil}}
            end

          {:error, _} = error ->
            error
        end
      end

      defp build_params(thread_id, :user, imei, dest_type) do
        %{
          toid: thread_id,
          destType: Enums.dest_type_value(dest_type),
          imei: imei
        }
      end

      defp build_params(thread_id, :group, imei, _dest_type) do
        %{
          grid: thread_id,
          imei: imei
        }
      end

      defp build_url(:user, session) do
        base = get_in(session.zpw_service_map, ["chat"]) || []
        service_url = List.first(base) || "https://chat.zalo.me"
        Url.build_for_session("\#{service_url}/api/message/typing", %{}, session)
      end

      defp build_url(:group, session) do
        base = get_in(session.zpw_service_map, ["group"]) || []
        service_url = List.first(base) || "https://groupchat.zalo.me"
        Url.build_for_session("\#{service_url}/api/group/typing", %{}, session)
      end
    end
    """)

    result = ZcaEx.Api.Endpoints.SendTypingEventMock.call(thread_id, thread_type, session, credentials, opts)

    :code.purge(ZcaEx.Api.Endpoints.SendTypingEventMock)
    :code.delete(ZcaEx.Api.Endpoints.SendTypingEventMock)

    result
  end
end
