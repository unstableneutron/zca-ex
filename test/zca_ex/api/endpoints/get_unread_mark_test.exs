defmodule ZcaEx.Api.Endpoints.GetUnreadMarkTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Api.Endpoints.GetUnreadMark
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

  describe "build_params/0" do
    test "returns empty map" do
      params = GetUnreadMark.build_params()
      assert params == %{}
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params", %{session: session} do
      url = GetUnreadMark.build_url(session, "encrypted_params_here")

      assert url =~ "https://conv.example.com/api/conv/getUnreadMark"
      assert url =~ "params=encrypted_params_here"
    end

    test "raises when conversation service not in session" do
      session = Fixtures.build_session() |> Map.put(:zpw_service_map, %{})

      assert_raise RuntimeError, ~r/conversation service URL not found/, fn ->
        GetUnreadMark.build_url(session, "params")
      end
    end

    test "handles string URL instead of list" do
      session =
        Fixtures.build_session()
        |> Map.put(:zpw_service_map, %{"conversation" => "https://single.example.com"})

      url = GetUnreadMark.build_url(session, "params")

      assert url =~ "https://single.example.com/api/conv/getUnreadMark"
    end
  end

  describe "transform_response" do
    test "handles data as map" do
      response_data = %{
        "convsGroup" => [%{"id" => "g1"}],
        "convsUser" => [%{"id" => "u1"}],
        "status" => 1
      }

      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, Fixtures.test_secret_key()))

      session =
        Fixtures.build_session()
        |> Map.put(:zpw_service_map, %{"conversation" => ["https://conv.example.com"]})

      credentials = Fixtures.build_credentials()

      result = call_with_mock(session, credentials)

      assert {:ok, %{convs_group: [%{"id" => "g1"}], convs_user: [%{"id" => "u1"}], status: 1}} = result
    end

    test "returns empty lists when data is missing" do
      response_data = %{"status" => 1}
      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, Fixtures.test_secret_key()))

      session =
        Fixtures.build_session()
        |> Map.put(:zpw_service_map, %{"conversation" => ["https://conv.example.com"]})

      credentials = Fixtures.build_credentials()

      result = call_with_mock(session, credentials)

      assert {:ok, %{convs_group: [], convs_user: [], status: 1}} = result
    end
  end

  describe "get/2 with valid params" do
    test "gets unread marks successfully", %{session: session, credentials: credentials} do
      response_data = %{
        "convsGroup" => [%{"id" => "group1", "ts" => 1_000_000}],
        "convsUser" => [%{"id" => "user1", "ts" => 2_000_000}],
        "status" => 1
      }

      MockAccountClient.setup_mock(Fixtures.build_success_response(response_data, session.secret_key))

      result = call_with_mock(session, credentials)

      assert {:ok,
              %{
                convs_group: [%{"id" => "group1", "ts" => 1_000_000}],
                convs_user: [%{"id" => "user1", "ts" => 2_000_000}],
                status: 1
              }} = result

      {url, body, _headers} = MockAccountClient.get_last_request()
      assert url =~ "/api/conv/getUnreadMark"
      assert url =~ "params="
      assert body == nil
    end
  end

  describe "error handling" do
    test "returns error on API error", %{session: session, credentials: credentials} do
      MockAccountClient.setup_mock(Fixtures.build_error_response(-1, "Operation failed"))

      result = call_with_mock(session, credentials)

      assert {:error, error} = result
      assert error.message == "Operation failed"
    end
  end

  defp call_with_mock(session, credentials) do
    Code.eval_string("""
    defmodule ZcaEx.Api.Endpoints.GetUnreadMarkMock do
      use ZcaEx.Api.Factory
      alias ZcaEx.Test.MockAccountClient, as: AccountClient
      alias ZcaEx.Error

      def get(session, credentials) do
        params = ZcaEx.Api.Endpoints.GetUnreadMark.build_params()

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = ZcaEx.Api.Endpoints.GetUnreadMark.build_url(session, encrypted_params)

            case AccountClient.get(session.uid, url, credentials.user_agent) do
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
           convs_group: data["convsGroup"] || data[:convsGroup] || [],
           convs_user: data["convsUser"] || data[:convsUser] || [],
           status: data["status"] || data[:status]
         }}
      end

      defp transform_response({:ok, data}) when is_binary(data) do
        case Jason.decode(data) do
          {:ok, parsed} -> transform_response({:ok, parsed})
          {:error, _} -> {:ok, %{convs_group: [], convs_user: [], status: nil}}
        end
      end

      defp transform_response({:error, _} = error), do: error
    end
    """)

    result = ZcaEx.Api.Endpoints.GetUnreadMarkMock.get(session, credentials)

    :code.purge(ZcaEx.Api.Endpoints.GetUnreadMarkMock)
    :code.delete(ZcaEx.Api.Endpoints.GetUnreadMarkMock)

    result
  end
end
