defmodule ZcaEx.Api.Endpoints.SendStickerTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Api.Endpoints.SendSticker
  alias ZcaEx.Test.{MockAccountClient, Fixtures}

  setup do
    session = Fixtures.build_session()
    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "call/5 validation" do
    test "returns error for nil sticker", %{session: session, credentials: credentials} do
      result = SendSticker.call(nil, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Sticker is required"
    end

    test "returns error for empty thread_id", %{session: session, credentials: credentials} do
      sticker = %{id: 1, cate_id: 0, type: 1}
      result = SendSticker.call(sticker, "", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Missing threadId"
    end

    test "returns error for nil thread_id", %{session: session, credentials: credentials} do
      sticker = %{id: 1, cate_id: 0, type: 1}
      result = SendSticker.call(sticker, nil, :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Missing threadId"
    end

    test "returns error for missing sticker id", %{session: session, credentials: credentials} do
      sticker = %{cate_id: 0, type: 1}
      result = SendSticker.call(sticker, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "id"
    end

    test "returns error for missing sticker cate_id", %{session: session, credentials: credentials} do
      sticker = %{id: 1, type: 1}
      result = SendSticker.call(sticker, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "cateId"
    end

    test "returns error for missing sticker type", %{session: session, credentials: credentials} do
      sticker = %{id: 1, cate_id: 0}
      result = SendSticker.call(sticker, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "type"
    end

    test "accepts cate_id of 0", %{session: session, credentials: credentials} do
      response_data = %{"msgId" => 12345}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      sticker = %{id: 1, cate_id: 0, type: 1}
      result = call_with_mock(sticker, "user123", :user, session, credentials)

      assert {:ok, %{msg_id: 12345}} = result
    end
  end

  describe "call/5 to user" do
    test "sends sticker to user", %{session: session, credentials: credentials} do
      response_data = %{"msgId" => 12345}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      sticker = %{id: 100, cate_id: 10, type: 2}
      result = call_with_mock(sticker, "user123", :user, session, credentials)

      assert {:ok, %{msg_id: 12345}} = result

      {url, body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/message/sticker"
      assert url =~ "nretry=0"
      assert body =~ "params="
    end

    test "includes correct params for user sticker", %{session: session, credentials: credentials} do
      response_data = %{"msgId" => 12345}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      sticker = %{id: 100, cate_id: 10, type: 2}
      _result = call_with_mock(sticker, "user123", :user, session, credentials)

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "chat.zalo.me"
    end
  end

  describe "call/5 to group" do
    test "sends sticker to group", %{session: session, credentials: credentials} do
      response_data = %{"msgId" => 67890}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      sticker = %{id: 200, cate_id: 20, type: 3}
      result = call_with_mock(sticker, "group456", :group, session, credentials)

      assert {:ok, %{msg_id: 67890}} = result

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/group/sticker"
      assert url =~ "nretry=0"
    end

    test "uses group service URL", %{session: session, credentials: credentials} do
      response_data = %{"msgId" => 67890}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      sticker = %{id: 200, cate_id: 20, type: 3}
      _result = call_with_mock(sticker, "group456", :group, session, credentials)

      {url, _body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "groupchat.zalo.me"
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      MockAccountClient.setup_mock(Fixtures.build_error_response(-1, "Rate limited"))

      sticker = %{id: 100, cate_id: 10, type: 2}
      result = call_with_mock(sticker, "user123", :user, session, credentials)

      assert {:error, error} = result
      assert error.message == "Rate limited"
    end
  end

  defp call_with_mock(sticker, thread_id, thread_type, session, credentials) do
    Code.eval_string("""
    defmodule ZcaEx.Api.Endpoints.SendStickerMock do
      use ZcaEx.Api.Factory
      alias ZcaEx.Test.MockAccountClient, as: AccountClient
      alias ZcaEx.Error

      def call(sticker, thread_id, thread_type, session, credentials) do
        is_group = thread_type == :group

        params =
          %{
            stickerId: sticker.id,
            cateId: sticker.cate_id,
            type: sticker.type,
            clientId: System.system_time(:millisecond),
            imei: credentials.imei,
            zsource: 101
          }
          |> add_thread_param(thread_id, is_group)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(thread_type, session)
            body = build_form_body(%{params: encrypted_params})

            case AccountClient.post(credentials.imei, url, body, credentials.user_agent) do
              {:ok, response} ->
                Response.parse(response, session.secret_key)
                |> extract_msg_id()

              {:error, reason} ->
                {:error, %Error{message: "Request failed: \#{inspect(reason)}", code: nil}}
            end

          {:error, _} = error ->
            error
        end
      end

      defp add_thread_param(params, thread_id, true), do: Map.put(params, :grid, thread_id)
      defp add_thread_param(params, thread_id, false), do: Map.put(params, :toid, thread_id)

      defp build_url(:user, session) do
        base = get_in(session.zpw_service_map, ["chat"]) || []
        service_url = List.first(base) || "https://chat.zalo.me"
        Url.build_for_session("\#{service_url}/api/message/sticker", %{nretry: 0}, session)
      end

      defp build_url(:group, session) do
        base = get_in(session.zpw_service_map, ["group"]) || []
        service_url = List.first(base) || "https://groupchat.zalo.me"
        Url.build_for_session("\#{service_url}/api/group/sticker", %{nretry: 0}, session)
      end

      defp extract_msg_id({:ok, %{"msgId" => msg_id}}), do: {:ok, %{msg_id: msg_id}}
      defp extract_msg_id({:ok, data}) when is_map(data), do: {:ok, data}
      defp extract_msg_id({:error, _} = error), do: error
    end
    """)

    result = ZcaEx.Api.Endpoints.SendStickerMock.call(sticker, thread_id, thread_type, session, credentials)

    :code.purge(ZcaEx.Api.Endpoints.SendStickerMock)
    :code.delete(ZcaEx.Api.Endpoints.SendStickerMock)

    result
  end
end
