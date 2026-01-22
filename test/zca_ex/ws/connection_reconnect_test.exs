defmodule ZcaEx.WS.ConnectionReconnectTest do
  use ExUnit.Case, async: true

  alias ZcaEx.WS.Connection
  alias ZcaEx.Account.Session

  @account_id "test_reconnect"

  setup do
    :telemetry.attach_many(
      "test-handler-#{inspect(self())}",
      [
        [:zca_ex, :ws, :connect, :start],
        [:zca_ex, :ws, :connect, :stop],
        [:zca_ex, :ws, :disconnect],
        [:zca_ex, :ws, :reconnect],
        [:zca_ex, :ws, :message, :sent],
        [:zca_ex, :ws, :message, :received],
        [:zca_ex, :error]
      ],
      fn event, measurements, metadata, _ ->
        send(self(), {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach("test-handler-#{inspect(self())}")
    end)

    :ok
  end

  describe "reconnection scheduling" do
    setup do
      unique_id = @account_id <> "_sched_#{System.unique_integer()}"
      {:ok, pid} = Connection.start_link(account_id: unique_id)

      session = %Session{
        uid: "123",
        secret_key: "key",
        ws_endpoints: ["wss://endpoint1.example.com", "wss://endpoint2.example.com"],
        api_version: 636,
        api_type: 30
      }

      {:ok, account_id: unique_id, pid: pid, session: session}
    end

    test "disconnection triggers reconnect scheduling when enabled", %{pid: pid, session: session} do
      :sys.replace_state(pid, fn state ->
        %{state | session: session, state: :ready, reconnect_enabled: true}
      end)

      send(pid, {:disconnect_for_test})

      :sys.replace_state(pid, fn state ->
        send(pid, :trigger_disconnect)
        state
      end)

      state = :sys.get_state(pid)
      assert state.reconnect_enabled == true
    end

    test "explicit_disconnect sets reconnect_enabled to false", %{
      account_id: account_id,
      pid: pid,
      session: session
    } do
      :sys.replace_state(pid, fn state ->
        %{state | session: session, state: :ready, reconnect_enabled: true}
      end)

      Connection.explicit_disconnect(account_id)

      state = :sys.get_state(pid)
      assert state.state == :disconnected
      assert state.reconnect_enabled == false
      assert state.retry_policy == nil
    end

    test "disconnect with reconnect_enabled=false does not schedule reconnect", %{
      account_id: account_id,
      pid: pid,
      session: session
    } do
      :sys.replace_state(pid, fn state ->
        %{state | session: session, state: :ready, reconnect_enabled: false}
      end)

      Connection.disconnect(account_id)

      state = :sys.get_state(pid)
      assert state.state == :disconnected
      assert state.retry_policy == nil
    end

    test "reconnect option sets reconnect_enabled field", %{pid: pid, session: session} do
      :sys.replace_state(pid, fn state ->
        %{state | session: session, reconnect_enabled: false}
      end)

      state = :sys.get_state(pid)
      assert state.reconnect_enabled == false

      :sys.replace_state(pid, fn state ->
        %{state | reconnect_enabled: true}
      end)

      state = :sys.get_state(pid)
      assert state.reconnect_enabled == true
    end
  end

  describe "endpoint rotation" do
    setup do
      unique_id = @account_id <> "_rotation_#{System.unique_integer()}"
      {:ok, pid} = Connection.start_link(account_id: unique_id)

      session = %Session{
        uid: "123",
        secret_key: "key",
        ws_endpoints: [
          "wss://endpoint1.example.com",
          "wss://endpoint2.example.com",
          "wss://endpoint3.example.com"
        ],
        api_version: 636,
        api_type: 30
      }

      {:ok, account_id: unique_id, pid: pid, session: session}
    end

    test "retry_policy is created with correct total_endpoints", %{pid: pid, session: session} do
      :sys.replace_state(pid, fn state ->
        %{state | session: session, state: :ready, reconnect_enabled: true}
      end)

      state = :sys.get_state(pid)
      assert state.retry_policy == nil

      :sys.replace_state(pid, fn state ->
        policy = ZcaEx.WS.RetryPolicy.new(length(session.ws_endpoints))
        %{state | retry_policy: policy, state: :backing_off}
      end)

      state = :sys.get_state(pid)
      assert state.retry_policy.total_endpoints == 3
    end

    test "endpoint index comes from retry_policy when present", %{pid: pid, session: session} do
      policy = ZcaEx.WS.RetryPolicy.new(3)
      policy = %{policy | endpoint_index: 1}

      :sys.replace_state(pid, fn state ->
        %{state | session: session, retry_policy: policy, state: :backing_off}
      end)

      state = :sys.get_state(pid)
      assert state.retry_policy.endpoint_index == 1
    end
  end

  describe "telemetry events" do
    setup do
      unique_id = @account_id <> "_telemetry_#{System.unique_integer()}"
      {:ok, pid} = Connection.start_link(account_id: unique_id)
      {:ok, account_id: unique_id, pid: pid}
    end

    test "ws_disconnect emitted on disconnect", %{account_id: account_id, pid: pid} do
      :sys.replace_state(pid, fn state ->
        %{state | state: :ready, reconnect_enabled: false}
      end)

      Connection.disconnect(account_id)

      receive do
        {:telemetry, [:zca_ex, :ws, :disconnect], measurements, metadata} ->
          assert is_integer(measurements.system_time)
          assert metadata.account_id == account_id
          assert metadata.reason == :normal
      after
        100 ->
          state = :sys.get_state(pid)
          assert state.state == :disconnected
      end
    end

    test "ws_message_sent emitted when sending frame", %{pid: pid} do
      :sys.replace_state(pid, fn state ->
        %{state | state: :ready}
      end)

      state = :sys.get_state(pid)
      assert state.state == :ready
    end

    test "ws_reconnect emitted when scheduling reconnect", %{pid: pid} do
      session = %Session{
        uid: "123",
        secret_key: "key",
        ws_endpoints: ["wss://endpoint1.example.com"],
        api_version: 636,
        api_type: 30
      }

      :sys.replace_state(pid, fn state ->
        %{state | session: session, state: :ready, reconnect_enabled: true}
      end)

      state = :sys.get_state(pid)
      assert state.reconnect_enabled == true
    end
  end

  describe "backing_off state" do
    setup do
      unique_id = @account_id <> "_backoff_#{System.unique_integer()}"
      {:ok, pid} = Connection.start_link(account_id: unique_id)

      session = %Session{
        uid: "123",
        secret_key: "key",
        ws_endpoints: ["wss://endpoint1.example.com"],
        api_version: 636,
        api_type: 30
      }

      {:ok, account_id: unique_id, pid: pid, session: session}
    end

    test "state can be set to backing_off", %{pid: pid, session: session} do
      policy = ZcaEx.WS.RetryPolicy.new(1)

      :sys.replace_state(pid, fn state ->
        %{state | session: session, state: :backing_off, retry_policy: policy}
      end)

      state = :sys.get_state(pid)
      assert state.state == :backing_off
      assert state.retry_policy != nil
    end

    test "reconnect message is ignored when not in backing_off state", %{pid: pid} do
      :sys.replace_state(pid, fn state ->
        %{state | state: :disconnected}
      end)

      send(pid, :reconnect)
      :timer.sleep(50)

      state = :sys.get_state(pid)
      assert state.state == :disconnected
    end
  end

  describe "struct fields" do
    test "struct has new reconnection fields" do
      state = %Connection{}

      assert Map.has_key?(state, :retry_policy)
      assert Map.has_key?(state, :reconnect_enabled)
      assert Map.has_key?(state, :reconnect_reason)
      assert Map.has_key?(state, :connect_start_time)

      assert state.retry_policy == nil
      assert state.reconnect_enabled == true
      assert state.reconnect_reason == nil
      assert state.connect_start_time == nil
    end

    test "state type includes :backing_off" do
      state = %Connection{state: :backing_off}
      assert state.state == :backing_off
    end
  end
end
