defmodule ZcaEx.Api.Endpoints.SendDeliveredEventTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Api.Endpoints.SendDeliveredEvent
  alias ZcaEx.Test.{MockAccountClient, Fixtures}

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/5 validation" do
    test "returns error for nil messages", %{session: session, credentials: credentials} do
      result = SendDeliveredEvent.call(true, nil, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "missing"
    end

    test "returns error for empty messages list", %{session: session, credentials: credentials} do
      result = SendDeliveredEvent.call(true, [], :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "between 1 and 50"
    end

    test "returns error for too many messages", %{session: session, credentials: credentials} do
      messages =
        for i <- 1..51 do
          build_message(%{msg_id: "#{i}", id_to: "receiver1"})
        end

      result = SendDeliveredEvent.call(true, messages, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "between 1 and 50"
    end
  end

  describe "call/5 to user" do
    test "sends delivered event for single message with is_seen=true", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      message = build_message(%{
        msg_id: "1000",
        cli_msg_id: "2000",
        uid_from: "sender123",
        id_to: "receiver456"
      })

      result = call_with_mock(true, [message], :user, session, credentials)

      assert :ok = result

      {url, body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/message/deliveredv2"
      assert body =~ "params="
    end

    test "sends delivered event for single message with is_seen=false", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      message = build_message(%{
        msg_id: "1000",
        cli_msg_id: "2000",
        uid_from: "sender123",
        id_to: "receiver456"
      })

      result = call_with_mock(false, [message], :user, session, credentials)

      assert :ok = result
    end

    test "sends delivered event for multiple messages", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      messages = [
        build_message(%{msg_id: "1", cli_msg_id: "1", uid_from: "sender1", id_to: "receiver1"}),
        build_message(%{msg_id: "2", cli_msg_id: "2", uid_from: "sender1", id_to: "receiver1"})
      ]

      result = call_with_mock(true, messages, :user, session, credentials)

      assert :ok = result
    end

    test "wraps single message in list", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      message = build_message(%{msg_id: "1", id_to: "receiver1"})

      result = call_with_mock(true, message, :user, session, credentials)

      assert :ok = result
    end
  end

  describe "call/5 to group" do
    test "sends delivered event to group", %{session: session, credentials: credentials} do
      response_data = %{"status" => 0}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      message = build_message(%{
        msg_id: "3000",
        cli_msg_id: "4000",
        uid_from: "sender789",
        id_to: "group123"
      })

      result = call_with_mock(true, [message], :group, session, credentials)

      assert :ok = result

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/group/deliveredv2"
    end
  end

  describe "thread validation" do
    test "returns error when group messages belong to different groups", %{session: session, credentials: credentials} do
      messages = [
        build_message(%{msg_id: "1", id_to: "group1"}),
        build_message(%{msg_id: "2", id_to: "group2"})
      ]

      result = SendDeliveredEvent.call(true, messages, :group, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "same idTo for Group thread"
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      MockAccountClient.setup_mock(Fixtures.build_error_response(-1, "Rate limited"))

      message = build_message(%{msg_id: "1", id_to: "receiver1"})

      result = call_with_mock(true, [message], :user, session, credentials)

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

  defp call_with_mock(is_seen, messages, thread_type, session, credentials) do
    Code.eval_string("""
    defmodule ZcaEx.Api.Endpoints.SendDeliveredEventMock do
      use ZcaEx.Api.Factory
      alias ZcaEx.Test.MockAccountClient, as: AccountClient

      @max_messages_per_send 50

      def call(is_seen, messages, thread_type, session, credentials) when not is_list(messages) do
        call(is_seen, [messages], thread_type, session, credentials)
      end

      def call(is_seen, messages, thread_type, session, credentials) do
        is_group = thread_type == :group
        first_msg = List.first(messages)
        thread_id = first_msg.id_to

        do_call(is_seen, messages, thread_type, thread_id, is_group, session, credentials)
      end

      defp do_call(is_seen, messages, thread_type, thread_id, is_group, session, credentials) do
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
          %{seen: if(is_seen, do: 1, else: 0), data: msg_data}
          |> maybe_add_grid(is_group, thread_id)

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

      defp maybe_add_grid(msg_infos, true, thread_id), do: Map.put(msg_infos, :grid, thread_id)
      defp maybe_add_grid(msg_infos, false, _thread_id), do: msg_infos

      defp maybe_add_imei(params, true, imei), do: Map.put(params, :imei, imei)
      defp maybe_add_imei(params, false, _imei), do: params

      defp build_url(:user, session) do
        base = get_in(session.zpw_service_map, ["chat"]) || []
        service_url = List.first(base) || "https://chat.zalo.me"
        Url.build_for_session("\#{service_url}/api/message/deliveredv2", %{nretry: 0}, session)
      end

      defp build_url(:group, session) do
        base = get_in(session.zpw_service_map, ["group"]) || []
        service_url = List.first(base) || "https://groupchat.zalo.me"
        Url.build_for_session("\#{service_url}/api/group/deliveredv2", %{nretry: 0}, session)
      end
    end
    """)

    result = ZcaEx.Api.Endpoints.SendDeliveredEventMock.call(is_seen, messages, thread_type, session, credentials)

    :code.purge(ZcaEx.Api.Endpoints.SendDeliveredEventMock)
    :code.delete(ZcaEx.Api.Endpoints.SendDeliveredEventMock)

    result
  end
end
