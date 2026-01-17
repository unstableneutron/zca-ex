defmodule ZcaEx.Account.RuntimeTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Account.Runtime
  alias ZcaEx.Events

  @default_config %{
    auto_login: true,
    ws: %{auto_connect: true, reconnect: true},
    login: %{retry: %{enabled: true, min_ms: 1000, max_ms: 30_000, factor: 2.0, jitter: 0.2}}
  }

  setup do
    account_id = "test-account-#{System.unique_integer([:positive])}"
    {:ok, account_id: account_id}
  end

  describe "initialization" do
    test "starts with default config", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      {:ok, status} = Runtime.status(account_id)

      assert status.config.ws == @default_config.ws
      assert status.config.login == @default_config.login
    end

    test "starts with custom config (auto_login: false)", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      {:ok, status} = Runtime.status(account_id)

      assert status.config.auto_login == false
    end

    test "subscribes to lifecycle events", %{account_id: account_id} do
      Events.subscribe(Events.topic(account_id, :runtime_started))
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      assert_receive {:zca_event, topic, %{config: _}}, 100
      assert topic =~ "runtime_started"
    end
  end

  describe "status/1" do
    test "returns phase and config", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      {:ok, status} = Runtime.status(account_id)

      assert is_atom(status.phase)
      assert is_map(status.config)
      assert Map.has_key?(status.config, :auto_login)
      assert Map.has_key?(status.config, :ws)
      assert Map.has_key?(status.config, :login)
    end
  end

  describe "configure/2" do
    test "merges config properly", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      :ok = Runtime.configure(account_id, auto_login: true)

      {:ok, status} = Runtime.status(account_id)
      assert status.config.auto_login == true
      assert status.config.ws == @default_config.ws
    end

    test "deep merges nested config", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      :ok = Runtime.configure(account_id, ws: %{auto_connect: false})

      {:ok, status} = Runtime.status(account_id)
      assert status.config.ws.auto_connect == false
      assert status.config.ws.reconnect == true
    end

    test "config changes trigger reconcile", %{account_id: account_id} do
      Events.subscribe(Events.topic(account_id, :login_start))
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      {:ok, status_before} = Runtime.status(account_id)
      assert status_before.phase == :idle

      :ok = Runtime.configure(account_id, auto_login: false)

      Process.sleep(50)
      {:ok, status_after} = Runtime.status(account_id)
      assert status_after.phase == :idle
    end
  end

  describe "stop/1" do
    test "sets phase to :stopped", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      :ok = Runtime.stop(account_id)

      {:ok, status} = Runtime.status(account_id)
      assert status.phase == :stopped
    end

    test "stopped state is sticky (ignores lifecycle events)", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)
      :ok = Runtime.stop(account_id)

      topic = Events.topic(account_id, :ready)
      Events.broadcast(topic, %{})

      Process.sleep(50)
      {:ok, status} = Runtime.status(account_id)
      assert status.phase == :stopped
    end

    test "stopped state ignores disconnected events", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)
      :ok = Runtime.stop(account_id)

      topic = Events.topic(account_id, :disconnected)
      Events.broadcast(topic, %{reason: :normal})

      Process.sleep(50)
      {:ok, status} = Runtime.status(account_id)
      assert status.phase == :stopped
    end
  end

  describe "state machine basics" do
    test "initial phase is :idle", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      {:ok, status} = Runtime.status(account_id)
      assert status.phase == :idle
    end

    test "with auto_login: false, stays idle after reconcile", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      Runtime.reconcile(account_id)
      Process.sleep(50)

      {:ok, status} = Runtime.status(account_id)
      assert status.phase == :idle
    end

    test "configure with auto_login: false keeps idle state", %{account_id: account_id} do
      {:ok, _pid} = start_runtime(account_id, auto_login: false)

      :ok = Runtime.configure(account_id, ws: %{auto_connect: false})
      Process.sleep(50)

      {:ok, status} = Runtime.status(account_id)
      assert status.phase == :idle
      assert status.config.auto_login == false
    end
  end

  defp start_runtime(account_id, opts) do
    runtime_config = Keyword.take(opts, [:auto_login, :ws, :login]) |> Map.new()

    start_supervised(
      {Runtime, account_id: account_id, runtime: runtime_config},
      id: {:runtime, account_id}
    )
  end
end
