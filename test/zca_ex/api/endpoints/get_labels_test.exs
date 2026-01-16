defmodule ZcaEx.Api.Endpoints.GetLabelsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetLabels
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "label" => ["https://label.zalo.me"]
      },
      api_type: 30,
      api_version: 645
    }

    {:ok, credentials} =
      Credentials.new(
        imei: "test-imei-12345",
        user_agent: "Mozilla/5.0 Test",
        cookies: [%{"name" => "test", "value" => "cookie"}],
        language: "vi"
      )

    {:ok, session: session, credentials: credentials}
  end

  describe "build_params/1" do
    test "builds params with imei" do
      params = GetLabels.build_params("test-imei-123")

      assert params == %{imei: "test-imei-123"}
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      url = GetLabels.build_base_url(session)

      assert url =~ "https://label.zalo.me/api/convlabel/get"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"label" => "https://label2.zalo.me"}}
      url = GetLabels.build_base_url(session)

      assert url =~ "https://label2.zalo.me/api/convlabel/get"
    end

    test "raises when service URL not found", %{session: session} do
      session = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/label service URL not found/, fn ->
        GetLabels.build_base_url(session)
      end
    end
  end

  describe "build_url/2" do
    test "builds URL with encrypted params in query", %{session: session} do
      encrypted = "encryptedParamsString123"
      url = GetLabels.build_url(session, encrypted)

      assert url =~ "https://label.zalo.me/api/convlabel/get"
      assert url =~ "params=encryptedParamsString123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "transform_response/1" do
    test "parses labelData JSON string" do
      data = %{
        "labelData" => ~s([{"id":"1","name":"Work"},{"id":"2","name":"Personal"}]),
        "version" => 5,
        "lastUpdateTime" => 1_234_567_890
      }

      result = GetLabels.transform_response(data)

      assert result.label_data == [
               %{"id" => "1", "name" => "Work"},
               %{"id" => "2", "name" => "Personal"}
             ]

      assert result.version == 5
      assert result.last_update_time == 1_234_567_890
    end

    test "handles labelData as already parsed list" do
      data = %{
        "labelData" => [%{"id" => "1", "name" => "Work"}],
        "version" => 3,
        "lastUpdateTime" => 1_234_567_890
      }

      result = GetLabels.transform_response(data)

      assert result.label_data == [%{"id" => "1", "name" => "Work"}]
    end

    test "handles empty labelData JSON string" do
      data = %{"labelData" => "[]", "version" => 1, "lastUpdateTime" => 1_000_000}

      result = GetLabels.transform_response(data)

      assert result.label_data == []
    end

    test "handles missing labelData" do
      data = %{"version" => 1, "lastUpdateTime" => 1_000_000}

      result = GetLabels.transform_response(data)

      assert result.label_data == []
    end

    test "handles nil labelData" do
      data = %{"labelData" => nil, "version" => 1, "lastUpdateTime" => 1_000_000}

      result = GetLabels.transform_response(data)

      assert result.label_data == []
    end

    test "handles invalid JSON in labelData" do
      data = %{"labelData" => "not valid json", "version" => 1, "lastUpdateTime" => 1_000_000}

      result = GetLabels.transform_response(data)

      assert result.label_data == []
    end

    test "handles atom keys in response" do
      data = %{labelData: ~s([{"id":"1"}]), version: 2, lastUpdateTime: 1_111_111}

      result = GetLabels.transform_response(data)

      assert result.label_data == [%{"id" => "1"}]
      assert result.version == 2
      assert result.last_update_time == 1_111_111
    end

    test "handles snake_case keys in response" do
      data = %{"label_data" => ~s([{"id":"1"}]), "version" => 2, "last_update_time" => 1_111_111}

      result = GetLabels.transform_response(data)

      assert result.label_data == [%{"id" => "1"}]
      assert result.last_update_time == 1_111_111
    end
  end
end
