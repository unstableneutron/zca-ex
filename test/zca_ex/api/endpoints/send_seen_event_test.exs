defmodule ZcaEx.Api.Endpoints.SendSeenEventTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Api.Endpoints.SendSeenEvent
  alias ZcaEx.Test.{MockAccountClient, Fixtures}

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/4 validation" do
    test "returns error for nil messages", %{session: session, credentials: credentials} do
      result = SendSeenEvent.call(nil, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "missing"
    end

    test "returns error for empty messages list", %{session: session, credentials: credentials} do
      result = SendSeenEvent.call([], :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "between 1 and 50"
    end

    test "returns error for too many messages", %{session: session, credentials: credentials} do
      messages =
        for i <- 1..51 do
          build_message(%{msg_id: "#{i}", uid_from: "sender1"})
        end

      result = SendSeenEvent.call(messages, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "between 1 and 50"
    end
  end

  describe "call/4 to user" do
    test "sends seen event for single message", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      message = build_message(%{
        msg_id: "1000",
        cli_msg_id: "2000",
        uid_from: "sender123",
        id_to: "receiver456"
      })

      result = call_with_mock([message], :user, session, credentials)

      assert :ok = result

      {url, body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/message/seenv2"
      assert body =~ "params="
    end

    test "sends seen event for multiple messages", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      messages = [
        build_message(%{msg_id: "1", cli_msg_id: "1", uid_from: "sender1", id_to: "me"}),
        build_message(%{msg_id: "2", cli_msg_id: "2", uid_from: "sender1", id_to: "me"})
      ]

      result = call_with_mock(messages, :user, session, credentials)

      assert :ok = result
    end

    test "wraps single message in list", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      message = build_message(%{msg_id: "1", uid_from: "sender1"})

      result = call_with_mock(message, :user, session, credentials)

      assert :ok = result
    end
  end

  describe "call/4 to group" do
    test "sends seen event to group", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      message = build_message(%{
        msg_id: "3000",
        cli_msg_id: "4000",
        uid_from: "sender789",
        id_to: "group123"
      })

      result = call_with_mock([message], :group, session, credentials)

      assert :ok = result

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/group/seenv2"
    end
  end

  describe "thread validation" do
    test "returns error when messages belong to different threads (user)", %{session: session, credentials: credentials} do
      messages = [
        build_message(%{msg_id: "1", uid_from: "sender1"}),
        build_message(%{msg_id: "2", uid_from: "sender2"})
      ]

      result = SendSeenEvent.call(messages, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "same thread"
    end

    test "returns error when messages belong to different threads (group)", %{session: session, credentials: credentials} do
      messages = [
        build_message(%{msg_id: "1", id_to: "group1"}),
        build_message(%{msg_id: "2", id_to: "group2"})
      ]

      result = SendSeenEvent.call(messages, :group, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "same thread"
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      MockAccountClient.setup_mock(Fixtures.build_error_response(-1, "Rate limited"))

      message = build_message(%{msg_id: "1", uid_from: "sender1"})

      result = call_with_mock([message], :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Rate limited"
    end
  end

  defp build_message(overrides) do
    defaults = %{
      msg_id: "default_msg_id",
      cli_msg_id: "default_cli_msg_id",
      uid_from: "default_uid_from",
      id_to: "default_id_to",
      msg_type: "1",
      st: 0,
      at: 0,
      cmd: 0,
      ts: "0"
    }

    Map.merge(defaults, overrides)
  end

  defp call_with_mock(messages, thread_type, session, credentials) do
    Code.eval_string("""
    defmodule ZcaEx.Api.Endpoints.SendSeenEventMock do
      use ZcaEx.Api.Factory
      alias ZcaEx.Test.MockAccountClient, as: AccountClient

      @max_messages_per_send 50

      def call(messages, thread_type, session, credentials) when not is_list(messages) do
        call([messages], thread_type, session, credentials)
      end

      def call(messages, thread_type, session, credentials) do
        is_group = thread_type == :group
        first_msg = List.first(messages)
        thread_id = if is_group, do: first_msg.id_to, else: first_msg.uid_from

        do_call(messages, thread_type, thread_id, session, credentials)
      end

      defp do_call(messages, thread_type, thread_id, session, credentials) do
        is_group = thread_type == :group

        msg_data =
          Enum.map(messages, fn msg ->
            %{
              gmi: msg.msg_id,
              cmi: msg.cli_msg_id,
              si: msg.uid_from,
              di: if(msg.id_to == session.uid, do: "0", else: msg.id_to),
              mt: msg.msg_type,
              st: get_optional_field(msg, :st, -1),
              at: get_optional_field(msg, :at, -1),
              cmd: get_optional_field(msg, :cmd, -1),
              ts: parse_ts(Map.get(msg, :ts))
            }
          end)

        msg_infos =
          %{data: msg_data}
          |> Map.put(if(is_group, do: :grid, else: :senderId), thread_id)

        params =
          %{msgInfos: Jason.encode!(msg_infos)}
          |> maybe_add_imei(is_group, credentials.imei)

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

      defp get_optional_field(msg, key, default) do
        case Map.get(msg, key) do
          nil -> default
          0 -> 0
          val when is_integer(val) -> val
          _ -> default
        end
      end

      defp parse_ts(nil), do: -1
      defp parse_ts(0), do: 0
      defp parse_ts(val) when is_integer(val), do: val

      defp parse_ts(val) when is_binary(val) do
        case Integer.parse(val) do
          {int, _} -> int
          :error -> -1
        end
      end

      defp maybe_add_imei(params, true, imei), do: Map.put(params, :imei, imei)
      defp maybe_add_imei(params, false, _imei), do: params

      defp build_url(:user, session) do
        base = get_in(session.zpw_service_map, ["chat"]) || []
        service_url = List.first(base) || "https://chat.zalo.me"
        Url.build_for_session("\#{service_url}/api/message/seenv2", %{nretry: 0}, session)
      end

      defp build_url(:group, session) do
        base = get_in(session.zpw_service_map, ["group"]) || []
        service_url = List.first(base) || "https://groupchat.zalo.me"
        Url.build_for_session("\#{service_url}/api/group/seenv2", %{nretry: 0}, session)
      end
    end
    """)

    result = ZcaEx.Api.Endpoints.SendSeenEventMock.call(messages, thread_type, session, credentials)

    :code.purge(ZcaEx.Api.Endpoints.SendSeenEventMock)
    :code.delete(ZcaEx.Api.Endpoints.SendSeenEventMock)

    result
  end
end
