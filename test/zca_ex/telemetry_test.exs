defmodule ZcaEx.TelemetryTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Telemetry

  setup do
    test_pid = self()
    handler_id = "test-handler-#{System.unique_integer()}"

    events = [
      [:zca_ex, :ws, :connect, :start],
      [:zca_ex, :ws, :connect, :stop],
      [:zca_ex, :ws, :disconnect],
      [:zca_ex, :ws, :reconnect],
      [:zca_ex, :ws, :message, :received],
      [:zca_ex, :ws, :message, :sent],
      [:zca_ex, :http, :request, :start],
      [:zca_ex, :http, :request, :stop],
      [:zca_ex, :account, :started],
      [:zca_ex, :account, :stopped],
      [:zca_ex, :error]
    ]

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  describe "ws_connect_start/2" do
    test "emits correct event with endpoint host extracted" do
      Telemetry.ws_connect_start("acc_123", "wss://chat.zalo.me/ws")

      assert_receive {:telemetry_event, [:zca_ex, :ws, :connect, :start], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.account_id == "acc_123"
      assert metadata.endpoint_host == "chat.zalo.me"
    end
  end

  describe "ws_connect_stop/3" do
    test "emits correct event with duration and result" do
      Telemetry.ws_connect_stop("acc_123", 1_000_000, :ok)

      assert_receive {:telemetry_event, [:zca_ex, :ws, :connect, :stop], measurements, metadata}
      assert measurements.duration == 1_000_000
      assert metadata.account_id == "acc_123"
      assert metadata.result == :ok
    end

    test "emits error result" do
      Telemetry.ws_connect_stop("acc_123", 500_000, :error)

      assert_receive {:telemetry_event, [:zca_ex, :ws, :connect, :stop], measurements, metadata}
      assert measurements.duration == 500_000
      assert metadata.result == :error
    end
  end

  describe "ws_disconnect/2" do
    test "emits correct event with reason" do
      Telemetry.ws_disconnect("acc_123", :normal)

      assert_receive {:telemetry_event, [:zca_ex, :ws, :disconnect], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.account_id == "acc_123"
      assert metadata.reason == :normal
    end
  end

  describe "ws_reconnect/4" do
    test "emits correct event with attempt info" do
      Telemetry.ws_reconnect("acc_123", 3, 1, 5000)

      assert_receive {:telemetry_event, [:zca_ex, :ws, :reconnect], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert measurements.attempt == 3
      assert measurements.delay_ms == 5000
      assert metadata.account_id == "acc_123"
      assert metadata.endpoint_index == 1
    end
  end

  describe "ws_message_received/3" do
    test "emits correct event with bytes and message type" do
      Telemetry.ws_message_received("acc_123", 256, :text)

      assert_receive {:telemetry_event, [:zca_ex, :ws, :message, :received], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert measurements.bytes == 256
      assert metadata.account_id == "acc_123"
      assert metadata.message_type == :text
    end
  end

  describe "ws_message_sent/2" do
    test "emits correct event with bytes" do
      Telemetry.ws_message_sent("acc_123", 128)

      assert_receive {:telemetry_event, [:zca_ex, :ws, :message, :sent], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert measurements.bytes == 128
      assert metadata.account_id == "acc_123"
    end
  end

  describe "http_request_start/3" do
    test "emits correct event with method and host" do
      Telemetry.http_request_start("acc_123", :post, "https://api.zalo.me/v1/messages")

      assert_receive {:telemetry_event, [:zca_ex, :http, :request, :start], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.account_id == "acc_123"
      assert metadata.method == :post
      assert metadata.endpoint_host == "api.zalo.me"
    end
  end

  describe "http_request_stop/3" do
    test "emits correct event with duration and status" do
      Telemetry.http_request_stop("acc_123", 2_000_000, 200)

      assert_receive {:telemetry_event, [:zca_ex, :http, :request, :stop], measurements, metadata}
      assert measurements.duration == 2_000_000
      assert metadata.account_id == "acc_123"
      assert metadata.status_code == 200
    end
  end

  describe "account_started/1" do
    test "emits correct event" do
      Telemetry.account_started("acc_123")

      assert_receive {:telemetry_event, [:zca_ex, :account, :started], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.account_id == "acc_123"
    end
  end

  describe "account_stopped/1" do
    test "emits correct event" do
      Telemetry.account_stopped("acc_123")

      assert_receive {:telemetry_event, [:zca_ex, :account, :stopped], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.account_id == "acc_123"
    end
  end

  describe "error/3" do
    test "emits correct event with category and reason" do
      Telemetry.error("acc_123", :websocket, :connection_refused)

      assert_receive {:telemetry_event, [:zca_ex, :error], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.account_id == "acc_123"
      assert metadata.category == :websocket
      assert metadata.reason == :connection_refused
    end
  end

  describe "span/3" do
    test "emits start and stop events" do
      test_pid = self()
      handler_id = "span-test-#{System.unique_integer()}"

      :telemetry.attach_many(
        handler_id,
        [
          [:zca_ex, :test, :start],
          [:zca_ex, :test, :stop]
        ],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      result = Telemetry.span([:zca_ex, :test], %{account_id: "acc_123"}, fn -> :result end)

      assert result == :result
      assert_receive {:telemetry_event, [:zca_ex, :test, :start], _, %{account_id: "acc_123"}}
      assert_receive {:telemetry_event, [:zca_ex, :test, :stop], %{duration: duration}, _}
      assert is_integer(duration)

      :telemetry.detach(handler_id)
    end
  end

  describe "event/3" do
    test "emits arbitrary events" do
      test_pid = self()
      handler_id = "event-test-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:zca_ex, :custom, :event],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      Telemetry.event([:zca_ex, :custom, :event], %{value: 42}, %{key: "test"})

      assert_receive {:telemetry_event, [:zca_ex, :custom, :event], %{value: 42}, %{key: "test"}}

      :telemetry.detach(handler_id)
    end
  end
end
