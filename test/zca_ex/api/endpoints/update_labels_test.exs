defmodule ZcaEx.Api.Endpoints.UpdateLabelsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateLabels
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

  describe "validate_label_data/1" do
    test "returns :ok for valid list" do
      assert :ok == UpdateLabels.validate_label_data([%{id: "1", name: "Work"}])
    end

    test "returns :ok for empty list" do
      assert :ok == UpdateLabels.validate_label_data([])
    end

    test "returns error for non-list" do
      assert {:error, %ZcaEx.Error{message: "label_data must be a list"}} =
               UpdateLabels.validate_label_data("not a list")
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "label_data must be a list"}} =
               UpdateLabels.validate_label_data(nil)
    end

    test "returns error for map" do
      assert {:error, %ZcaEx.Error{message: "label_data must be a list"}} =
               UpdateLabels.validate_label_data(%{id: "1"})
    end
  end

  describe "validate_version/1" do
    test "returns :ok for zero" do
      assert :ok == UpdateLabels.validate_version(0)
    end

    test "returns :ok for positive integer" do
      assert :ok == UpdateLabels.validate_version(42)
    end

    test "returns error for negative integer" do
      assert {:error, %ZcaEx.Error{message: "version must be a non-negative integer"}} =
               UpdateLabels.validate_version(-1)
    end

    test "returns error for float" do
      assert {:error, %ZcaEx.Error{message: "version must be a non-negative integer"}} =
               UpdateLabels.validate_version(1.5)
    end

    test "returns error for string" do
      assert {:error, %ZcaEx.Error{message: "version must be a non-negative integer"}} =
               UpdateLabels.validate_version("5")
    end

    test "returns error for nil" do
      assert {:error, %ZcaEx.Error{message: "version must be a non-negative integer"}} =
               UpdateLabels.validate_version(nil)
    end
  end

  describe "build_params/3" do
    test "builds params with all fields" do
      label_data_json = ~s([{"id":"1","name":"Work"}])
      params = UpdateLabels.build_params(label_data_json, 5, "test-imei")

      assert params == %{
               labelData: label_data_json,
               version: 5,
               imei: "test-imei"
             }
    end
  end

  describe "build_url/1" do
    test "builds correct URL without params in query", %{session: session} do
      url = UpdateLabels.build_url(session)

      assert url =~ "https://label.zalo.me/api/convlabel/update"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
      refute url =~ "params="
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"label" => "https://label2.zalo.me"}}
      url = UpdateLabels.build_url(session)

      assert url =~ "https://label2.zalo.me/api/convlabel/update"
    end

    test "raises when service URL not found", %{session: session} do
      session = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/label service URL not found/, fn ->
        UpdateLabels.build_url(session)
      end
    end
  end

  describe "transform_response/1" do
    test "parses labelData JSON string" do
      data = %{
        "labelData" => ~s([{"id":"1","name":"Work"},{"id":"2","name":"Personal"}]),
        "version" => 6,
        "lastUpdateTime" => 1_234_567_890
      }

      result = UpdateLabels.transform_response(data)

      assert result.label_data == [
               %{"id" => "1", "name" => "Work"},
               %{"id" => "2", "name" => "Personal"}
             ]

      assert result.version == 6
      assert result.last_update_time == 1_234_567_890
    end

    test "handles labelData as already parsed list" do
      data = %{
        "labelData" => [%{"id" => "1", "name" => "Work"}],
        "version" => 3,
        "lastUpdateTime" => 1_234_567_890
      }

      result = UpdateLabels.transform_response(data)

      assert result.label_data == [%{"id" => "1", "name" => "Work"}]
    end

    test "handles empty labelData JSON string" do
      data = %{"labelData" => "[]", "version" => 1, "lastUpdateTime" => 1_000_000}

      result = UpdateLabels.transform_response(data)

      assert result.label_data == []
    end

    test "handles missing labelData" do
      data = %{"version" => 1, "lastUpdateTime" => 1_000_000}

      result = UpdateLabels.transform_response(data)

      assert result.label_data == []
    end

    test "handles nil labelData" do
      data = %{"labelData" => nil, "version" => 1, "lastUpdateTime" => 1_000_000}

      result = UpdateLabels.transform_response(data)

      assert result.label_data == []
    end

    test "handles invalid JSON in labelData" do
      data = %{"labelData" => "not valid json", "version" => 1, "lastUpdateTime" => 1_000_000}

      result = UpdateLabels.transform_response(data)

      assert result.label_data == []
    end

    test "handles atom keys in response" do
      data = %{labelData: ~s([{"id":"1"}]), version: 2, lastUpdateTime: 1_111_111}

      result = UpdateLabels.transform_response(data)

      assert result.label_data == [%{"id" => "1"}]
      assert result.version == 2
      assert result.last_update_time == 1_111_111
    end

    test "handles snake_case keys in response" do
      data = %{"label_data" => ~s([{"id":"1"}]), "version" => 2, "last_update_time" => 1_111_111}

      result = UpdateLabels.transform_response(data)

      assert result.label_data == [%{"id" => "1"}]
      assert result.last_update_time == 1_111_111
    end
  end

  describe "update/4 validation" do
    test "returns error when label_data is not a list", %{
      session: session,
      credentials: credentials
    } do
      assert {:error, %ZcaEx.Error{message: "label_data must be a list"}} =
               UpdateLabels.update("not a list", 1, session, credentials)
    end

    test "returns error when version is negative", %{session: session, credentials: credentials} do
      assert {:error, %ZcaEx.Error{message: "version must be a non-negative integer"}} =
               UpdateLabels.update([], -1, session, credentials)
    end

    test "returns error when version is not an integer", %{
      session: session,
      credentials: credentials
    } do
      assert {:error, %ZcaEx.Error{message: "version must be a non-negative integer"}} =
               UpdateLabels.update([], "5", session, credentials)
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/label service URL not found/, fn ->
        UpdateLabels.update([], 0, session, credentials)
      end
    end
  end
end
