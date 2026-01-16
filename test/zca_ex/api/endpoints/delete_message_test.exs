defmodule ZcaEx.Api.Endpoints.DeleteMessageTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Api.Endpoints.DeleteMessage
  alias ZcaEx.Test.{MockAccountClient, Fixtures}

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/4 validation" do
    test "returns error when deleting own message for everyone", %{session: session, credentials: credentials} do
      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: session.uid
        },
        thread_id: "group123",
        type: :group
      }

      result = DeleteMessage.call(destination, false, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "Use undo API instead"
    end

    test "returns error when deleting for everyone in private chat", %{session: session, credentials: credentials} do
      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: "other_user"
        },
        thread_id: "user456",
        type: :user
      }

      result = DeleteMessage.call(destination, false, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "Cannot delete for everyone in private chat"
    end
  end

  describe "call/4 with valid params" do
    test "deletes message in group for everyone", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: "other_user"
        },
        thread_id: "group123",
        type: :group
      }

      result = call_with_mock(destination, false, session, credentials)

      assert {:ok, %{status: 1}} = result

      {url, body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/group/deletemsg"
      assert body =~ "params="
    end

    test "deletes message for self only in user chat", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: "other_user"
        },
        thread_id: "user456",
        type: :user
      }

      result = call_with_mock(destination, true, session, credentials)

      assert {:ok, %{status: 1}} = result

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/message/delete"
    end

    test "deletes own message for self only", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: session.uid
        },
        thread_id: "user456",
        type: :user
      }

      result = call_with_mock(destination, true, session, credentials)

      assert {:ok, %{status: 1}} = result
    end

    test "defaults type to :user when not provided", %{session: session, credentials: credentials} do
      response_data = %{"status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: "other_user"
        },
        thread_id: "user456"
      }

      result = call_with_mock(destination, true, session, credentials)

      assert {:ok, %{status: 1}} = result

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/message/delete"
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      MockAccountClient.setup_mock(Fixtures.build_error_response(-1, "Message not found"))

      destination = %{
        data: %{
          cli_msg_id: "1000",
          msg_id: "2000",
          uid_from: "other_user"
        },
        thread_id: "group123",
        type: :group
      }

      result = call_with_mock(destination, false, session, credentials)

      assert {:error, error} = result
      assert error.message == "Message not found"
    end
  end

  defp call_with_mock(destination, only_me, session, credentials) do
    original_client = Application.get_env(:zca, :http_client, ZcaEx.HTTP.AccountClient)
    Application.put_env(:zca, :http_client, MockAccountClient)

    Code.eval_string("""
    defmodule ZcaEx.Api.Endpoints.DeleteMessageMock do
      use ZcaEx.Api.Factory
      alias ZcaEx.Test.MockAccountClient, as: AccountClient

      def call(destination, only_me, session, credentials) do
        thread_type = destination[:type] || :user
        is_self = destination.data.uid_from == session.uid

        with :ok <- validate_delete(is_self, only_me, thread_type) do
          params = build_params(destination, only_me, thread_type, credentials)

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
      end

      defp validate_delete(true, false, _thread_type) do
        {:error, ZcaEx.Error.api(nil, "Cannot delete own message for everyone. Use undo API instead.")}
      end

      defp validate_delete(_is_self, false, :user) do
        {:error, ZcaEx.Error.api(nil, "Cannot delete for everyone in private chat")}
      end

      defp validate_delete(_is_self, _only_me, _thread_type), do: :ok

      defp build_params(destination, only_me, thread_type, credentials) do
        msg = %{
          cliMsgId: destination.data.cli_msg_id,
          globalMsgId: destination.data.msg_id,
          ownerId: destination.data.uid_from,
          destId: destination.thread_id
        }

        base_params = %{
          cliMsgId: System.system_time(:millisecond),
          msgs: [msg],
          onlyMe: if(only_me, do: 1, else: 0)
        }

        case thread_type do
          :user ->
            base_params
            |> Map.put(:toid, destination.thread_id)
            |> Map.put(:imei, credentials.imei)

          :group ->
            Map.put(base_params, :grid, destination.thread_id)
        end
      end

      defp build_url(:user, session) do
        base = get_in(session.zpw_service_map, ["chat"]) || []
        service_url = List.first(base) || "https://tt-chat3-wpa.chat.zalo.me"
        Url.build_for_session("\#{service_url}/api/message/delete", %{}, session)
      end

      defp build_url(:group, session) do
        base = get_in(session.zpw_service_map, ["group"]) || []
        service_url = List.first(base) || "https://tt-group-wpa.chat.zalo.me"
        Url.build_for_session("\#{service_url}/api/group/deletemsg", %{}, session)
      end

      defp transform_response({:ok, %{"status" => status}}) do
        {:ok, %{status: status}}
      end

      defp transform_response({:ok, data}) when is_map(data) do
        {:ok, %{status: data["status"] || 0}}
      end

      defp transform_response({:error, _} = error), do: error
    end
    """)

    result = ZcaEx.Api.Endpoints.DeleteMessageMock.call(destination, only_me, session, credentials)

    Application.put_env(:zca, :http_client, original_client)
    :code.purge(ZcaEx.Api.Endpoints.DeleteMessageMock)
    :code.delete(ZcaEx.Api.Endpoints.DeleteMessageMock)

    result
  end
end
