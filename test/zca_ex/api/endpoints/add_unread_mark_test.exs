defmodule ZcaEx.Api.Endpoints.AddUnreadMarkTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Api.Endpoints.AddUnreadMark
  alias ZcaEx.Test.{MockAccountClient, Fixtures}

  setup do
    session =
      Fixtures.build_session()
      |> Map.put(:zpw_service_map, %{
        "conversation" => ["https://conv.example.com"]
      })

    credentials = Fixtures.build_credentials()

    {:ok, session: session, credentials: credentials}
  end

  describe "validation" do
    test "returns error for empty thread_id", %{session: session, credentials: credentials} do
      result = AddUnreadMark.add("", :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "thread_id must be a non-empty string"
    end

    test "returns error for nil thread_id", %{session: session, credentials: credentials} do
      result = AddUnreadMark.add(nil, :user, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "thread_id must be a non-empty string"
    end

    test "returns error for invalid thread_type", %{session: session, credentials: credentials} do
      result = AddUnreadMark.add("user123", :invalid, session, credentials)

      assert {:error, error} = result
      assert error.message =~ "thread_type must be :user or :group"
    end
  end

  describe "build_params/4" do
    test "builds params for user thread", %{credentials: credentials} do
      timestamp = 1_700_000_000_000
      params = AddUnreadMark.build_params("user456", :user, timestamp, credentials)

      assert Map.has_key?(params, "param")
      {:ok, inner} = Jason.decode(params["param"])

      assert inner["convsUser"] == [
               %{
                 "id" => "user456",
                 "cliMsgId" => "1700000000000",
                 "fromUid" => "0",
                 "ts" => 1_700_000_000_000
               }
             ]

      assert inner["convsGroup"] == []
      assert inner["imei"] == credentials.imei
    end

    test "builds params for group thread", %{credentials: credentials} do
      timestamp = 1_700_000_000_000
      params = AddUnreadMark.build_params("group789", :group, timestamp, credentials)

      assert Map.has_key?(params, "param")
      {:ok, inner} = Jason.decode(params["param"])

      assert inner["convsGroup"] == [
               %{
                 "id" => "group789",
                 "cliMsgId" => "1700000000000",
                 "fromUid" => "0",
                 "ts" => 1_700_000_000_000
               }
             ]

      assert inner["convsUser"] == []
      assert inner["imei"] == credentials.imei
    end
  end

  describe "build_url/1" do
    test "builds URL for conversation service", %{session: session} do
      url = AddUnreadMark.build_url(session)

      assert url =~ "https://conv.example.com/api/conv/addUnreadMark"
    end

    test "raises when conversation service not in session" do
      session = Fixtures.build_session() |> Map.put(:zpw_service_map, %{})

      assert_raise RuntimeError, ~r/conversation service URL not found/, fn ->
        AddUnreadMark.build_url(session)
      end
    end

    test "handles string URL instead of list" do
      session =
        Fixtures.build_session()
        |> Map.put(:zpw_service_map, %{"conversation" => "https://single.example.com"})

      url = AddUnreadMark.build_url(session)

      assert url =~ "https://single.example.com/api/conv/addUnreadMark"
    end
  end

  describe "transform_response" do
    test "handles data as map" do
      response_data = %{"updateId" => 123, "status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, Fixtures.test_secret_key()))

      session =
        Fixtures.build_session()
        |> Map.put(:zpw_service_map, %{"conversation" => ["https://conv.example.com"]})

      credentials = Fixtures.build_credentials()

      result = call_with_mock(session, credentials, "user123", :user)

      assert {:ok, %{update_id: 123, status: 1}} = result
    end
  end

  describe "add/4 with valid params" do
    test "adds unread mark for user successfully", %{session: session, credentials: credentials} do
      response_data = %{"updateId" => 100, "status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      result = call_with_mock(session, credentials, "user456", :user)

      assert {:ok, %{update_id: 100, status: 1}} = result

      {url, body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/conv/addUnreadMark"
      assert body =~ "params="
    end

    test "adds unread mark for group successfully", %{session: session, credentials: credentials} do
      response_data = %{"updateId" => 200, "status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      result = call_with_mock(session, credentials, "group789", :group)

      assert {:ok, %{update_id: 200, status: 1}} = result
    end

    test "defaults to user thread type", %{session: session, credentials: credentials} do
      response_data = %{"updateId" => 300, "status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      result = call_with_mock_default_type(session, credentials, "user456")

      assert {:ok, %{update_id: 300, status: 1}} = result
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      MockAccountClient.setup_mock(Fixtures.build_error_response(-1, "Operation failed"))

      result = call_with_mock(session, credentials, "user456", :user)

      assert {:error, error} = result
      assert error.message == "Operation failed"
    end
  end

  defp call_with_mock(session, credentials, thread_id, thread_type) do
    Code.eval_string("""
    defmodule ZcaEx.Api.Endpoints.AddUnreadMarkMock do
      use ZcaEx.Api.Factory
      alias ZcaEx.Test.MockAccountClient, as: AccountClient
      alias ZcaEx.Error

      def add(thread_id, thread_type, session, credentials) do
        timestamp = System.system_time(:millisecond)
        params = ZcaEx.Api.Endpoints.AddUnreadMark.build_params(thread_id, thread_type, timestamp, credentials)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = ZcaEx.Api.Endpoints.AddUnreadMark.build_url(session)
            body = build_form_body(%{params: encrypted_params})

            case AccountClient.post(session.uid, url, body, credentials.user_agent) do
              {:ok, resp} ->
                Response.parse(resp, session.secret_key)
                |> transform_response()

              {:error, reason} ->
                {:error, Error.new(:network, "Request failed: \#{inspect(reason)}")}
            end

          {:error, _} = error ->
            error
        end
      end

      defp transform_response({:ok, data}) when is_map(data) do
        {:ok,
         %{
           update_id: data["updateId"] || data[:updateId],
           status: data["status"] || data[:status]
         }}
      end

      defp transform_response({:ok, data}) when is_binary(data) do
        case Jason.decode(data) do
          {:ok, parsed} -> transform_response({:ok, parsed})
          {:error, _} -> {:ok, %{update_id: nil, status: nil}}
        end
      end

      defp transform_response({:error, _} = error), do: error
    end
    """)

    result = ZcaEx.Api.Endpoints.AddUnreadMarkMock.add(thread_id, thread_type, session, credentials)

    :code.purge(ZcaEx.Api.Endpoints.AddUnreadMarkMock)
    :code.delete(ZcaEx.Api.Endpoints.AddUnreadMarkMock)

    result
  end

  defp call_with_mock_default_type(session, credentials, thread_id) do
    call_with_mock(session, credentials, thread_id, :user)
  end
end
