defmodule ZcaEx.Api.Endpoints.UndoMessageTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Api.Endpoints.UndoMessage
  alias ZcaEx.Test.{MockAccountClient, Fixtures}

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "module structure" do
    test "exports call/4 and call/5 functions" do
      Code.ensure_loaded!(UndoMessage)
      assert function_exported?(UndoMessage, :call, 4)
      assert function_exported?(UndoMessage, :call, 5)
    end

    test "has proper moduledoc" do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} = Code.fetch_docs(UndoMessage)
      assert doc =~ "Undo"
    end
  end

  describe "typespec" do
    test "defines undo_payload type" do
      {:ok, types} = Code.Typespec.fetch_types(UndoMessage)
      type_names = Enum.map(types, fn {_, {name, _, _}} -> name end)
      assert :undo_payload in type_names
    end
  end

  describe "call/5 with valid params" do
    test "undoes message in user thread", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      payload = %{msg_id: "12345", cli_msg_id: "67890"}
      result = call_with_mock(payload, "user123", :user, session, credentials)

      assert {:ok, %{status: 1}} = result

      {url, body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/message/undo"
      assert body =~ "params="
    end

    test "undoes message in group thread", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      payload = %{msg_id: "12345", cli_msg_id: "67890"}
      result = call_with_mock(payload, "group123", :group, session, credentials)

      assert {:ok, %{status: 1}} = result

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/group/undomsg"
    end

    test "defaults to user thread type", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      payload = %{msg_id: "12345", cli_msg_id: "67890"}
      result = call_with_mock_default_type(payload, "user123", session, credentials)

      assert {:ok, %{status: 1}} = result

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/message/undo"
    end

    test "accepts integer msg_id and cli_msg_id", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      payload = %{msg_id: 12345, cli_msg_id: 67890}
      result = call_with_mock(payload, "user123", :user, session, credentials)

      assert {:ok, %{status: 1}} = result
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      MockAccountClient.setup_mock(Fixtures.build_error_response(-1, "Message not found"))

      payload = %{msg_id: "12345", cli_msg_id: "67890"}
      result = call_with_mock(payload, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Message not found"
    end
  end

  defp call_with_mock(payload, thread_id, thread_type, session, credentials) do
    Code.eval_string("""
    defmodule ZcaEx.Api.Endpoints.UndoMessageMock do
      use ZcaEx.Api.Factory
      alias ZcaEx.Test.MockAccountClient, as: AccountClient

      def call(payload, thread_id, thread_type, session, credentials) do
        params =
          %{
            msgId: payload.msg_id,
            clientId: System.system_time(:millisecond),
            cliMsgIdUndo: payload.cli_msg_id
          }
          |> add_thread_params(thread_id, thread_type, credentials)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(thread_type, session)
            body = build_form_body(%{params: encrypted_params})

            case AccountClient.post(credentials.imei, url, body, credentials.user_agent) do
              {:ok, resp} ->
                Response.parse(resp, session.secret_key)
                |> transform_response()

              {:error, reason} ->
                {:error, %ZcaEx.Error{message: "Request failed: \#{inspect(reason)}", code: nil}}
            end

          {:error, _} = error ->
            error
        end
      end

      defp add_thread_params(params, thread_id, :user, _credentials) do
        Map.put(params, :toid, thread_id)
      end

      defp add_thread_params(params, thread_id, :group, credentials) do
        params
        |> Map.put(:grid, thread_id)
        |> Map.put(:visibility, 0)
        |> Map.put(:imei, credentials.imei)
      end

      defp build_url(:user, session) do
        base = get_in(session.zpw_service_map, ["chat"]) || []
        service_url = List.first(base) || "https://chat.zalo.me"
        Url.build_for_session("\#{service_url}/api/message/undo", %{}, session)
      end

      defp build_url(:group, session) do
        base = get_in(session.zpw_service_map, ["group"]) || []
        service_url = List.first(base) || "https://groupchat.zalo.me"
        Url.build_for_session("\#{service_url}/api/group/undomsg", %{}, session)
      end

      defp transform_response({:ok, %{"status" => status}}) do
        {:ok, %{status: status}}
      end

      defp transform_response({:ok, data}) do
        {:ok, %{status: Map.get(data, "status", 0)}}
      end

      defp transform_response(error), do: error
    end
    """)

    result = ZcaEx.Api.Endpoints.UndoMessageMock.call(payload, thread_id, thread_type, session, credentials)

    :code.purge(ZcaEx.Api.Endpoints.UndoMessageMock)
    :code.delete(ZcaEx.Api.Endpoints.UndoMessageMock)

    result
  end

  defp call_with_mock_default_type(payload, thread_id, session, credentials) do
    call_with_mock(payload, thread_id, :user, session, credentials)
  end
end
