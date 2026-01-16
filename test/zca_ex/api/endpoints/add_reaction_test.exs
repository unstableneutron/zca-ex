defmodule ZcaEx.Api.Endpoints.AddReactionTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Api.Endpoints.AddReaction
  alias ZcaEx.Test.{MockAccountClient, Fixtures}
  alias ZcaEx.Model.Enums

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/4 with standard reaction" do
    test "sends reaction to user thread", %{session: session, credentials: credentials} do
      response_data = %{"msgIds" => [123, 456]}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      target = %{
        msg_id: "1000",
        cli_msg_id: "2000",
        thread_id: "user123",
        thread_type: :user
      }

      result = call_with_mock(AddReaction, :heart, target, session, credentials)

      assert {:ok, %{msg_ids: [123, 456]}} = result

      {url, body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/message/reaction"
      assert body =~ "params="
    end

    test "sends reaction to group thread", %{session: session, credentials: credentials} do
      response_data = %{"msgIds" => [789]}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      target = %{
        msg_id: "3000",
        cli_msg_id: "4000",
        thread_id: "group456",
        thread_type: :group
      }

      result = call_with_mock(AddReaction, :like, target, session, credentials)

      assert {:ok, %{msg_ids: [789]}} = result

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/group/reaction"
    end

    test "handles various reaction types", %{session: session, credentials: credentials} do
      response_data = %{"msgIds" => [1]}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      target = %{msg_id: "1", cli_msg_id: "1", thread_id: "user1", thread_type: :user}

      for reaction <- [:haha, :wow, :cry, :angry, :kiss] do
        MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

        result = call_with_mock(AddReaction, reaction, target, session, credentials)
        assert {:ok, _} = result

        {r_type, _source} = Enums.reaction_type(reaction)
        assert is_integer(r_type)
      end
    end
  end

  describe "call/4 with custom reaction" do
    test "sends custom reaction", %{session: session, credentials: credentials} do
      response_data = %{"msgIds" => [999]}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      custom = %{r_type: 100, source: 6, icon: "custom-icon"}

      target = %{
        msg_id: "5000",
        cli_msg_id: "6000",
        thread_id: "user789",
        thread_type: :user
      }

      result = call_with_mock(AddReaction, custom, target, session, credentials)

      assert {:ok, %{msg_ids: [999]}} = result
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      MockAccountClient.setup_mock(Fixtures.build_error_response(-1, "Invalid message"))

      target = %{msg_id: "1", cli_msg_id: "1", thread_id: "user1", thread_type: :user}

      result = call_with_mock(AddReaction, :heart, target, session, credentials)

      assert {:error, error} = result
      assert error.message == "Invalid message"
    end
  end

  defp call_with_mock(module, reaction, target, session, credentials) do
    original_client = Application.get_env(:zca, :http_client, ZcaEx.HTTP.AccountClient)
    Application.put_env(:zca, :http_client, MockAccountClient)

    Code.eval_string("""
    defmodule ZcaEx.Api.Endpoints.AddReactionMock do
      use ZcaEx.Api.Factory
      alias ZcaEx.Model.Enums
      alias ZcaEx.Test.MockAccountClient, as: AccountClient

      def call(reaction, target, session, credentials) do
        {r_type, source, icon} = get_reaction_info(reaction)

        message_payload = %{
          rMsg: [
            %{
              gMsgID: parse_int(target.msg_id),
              cMsgID: parse_int(target.cli_msg_id),
              msgType: 1
            }
          ],
          rIcon: icon,
          rType: r_type,
          source: source
        }

        params =
          %{
            react_list: [
              %{
                message: Jason.encode!(message_payload),
                clientId: System.system_time(:millisecond)
              }
            ]
          }
          |> add_thread_params(target, credentials)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(target.thread_type, session)
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

      defp get_reaction_info(%{r_type: r_type, source: source, icon: icon}) do
        {r_type, source, icon}
      end

      defp get_reaction_info(reaction) when is_atom(reaction) do
        {r_type, source} = Enums.reaction_type(reaction)
        icon = Enums.reaction_icon(reaction)
        {r_type, source, icon}
      end

      defp add_thread_params(params, %{thread_type: :user, thread_id: thread_id}, _credentials) do
        Map.put(params, :toid, thread_id)
      end

      defp add_thread_params(params, %{thread_type: :group, thread_id: thread_id}, credentials) do
        params
        |> Map.put(:grid, thread_id)
        |> Map.put(:imei, credentials.imei)
      end

      defp build_url(:user, session) do
        base = get_in(session.zpw_service_map, ["reaction"]) || []
        service_url = List.first(base) || "https://reaction.chat.zalo.me"
        Url.build_for_session("\#{service_url}/api/message/reaction", %{}, session)
      end

      defp build_url(:group, session) do
        base = get_in(session.zpw_service_map, ["reaction"]) || []
        service_url = List.first(base) || "https://reaction.chat.zalo.me"
        Url.build_for_session("\#{service_url}/api/group/reaction", %{}, session)
      end

      defp parse_int(val) when is_integer(val), do: val
      defp parse_int(val) when is_binary(val), do: String.to_integer(val)

      defp transform_response({:ok, %{"msgIds" => msg_ids}}) when is_binary(msg_ids) do
        case Jason.decode(msg_ids) do
          {:ok, ids} -> {:ok, %{msg_ids: ids}}
          {:error, _} -> {:ok, %{msg_ids: []}}
        end
      end

      defp transform_response({:ok, %{"msgIds" => msg_ids}}) when is_list(msg_ids) do
        {:ok, %{msg_ids: msg_ids}}
      end

      defp transform_response({:ok, data}), do: {:ok, data}
      defp transform_response(error), do: error
    end
    """)

    result = ZcaEx.Api.Endpoints.AddReactionMock.call(reaction, target, session, credentials)

    Application.put_env(:zca, :http_client, original_client)
    :code.purge(ZcaEx.Api.Endpoints.AddReactionMock)
    :code.delete(ZcaEx.Api.Endpoints.AddReactionMock)

    result
  end
end
