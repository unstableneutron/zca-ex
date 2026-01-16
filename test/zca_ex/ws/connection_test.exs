defmodule ZcaEx.WS.ConnectionTest do
  use ExUnit.Case, async: true

  alias ZcaEx.WS.Connection
  alias ZcaEx.Account.Session

  @account_id "test_account_123"

  describe "start_link/1" do
    test "starts with disconnected state" do
      opts = [account_id: @account_id <> "_start"]
      {:ok, pid} = Connection.start_link(opts)
      assert Process.alive?(pid)

      state = :sys.get_state(pid)
      assert state.state == :disconnected
      assert state.account_id == @account_id <> "_start"
      assert state.conn == nil
      assert state.websocket == nil
      assert state.cipher_key == nil
    end

    test "registers with the Registry" do
      unique_id = @account_id <> "_registry_#{System.unique_integer()}"
      opts = [account_id: unique_id]
      {:ok, _pid} = Connection.start_link(opts)

      assert [{pid, nil}] = Registry.lookup(ZcaEx.Registry, {:ws, unique_id})
      assert Process.alive?(pid)
    end

    test "accepts custom user_agent option" do
      opts = [account_id: @account_id <> "_ua", user_agent: "Custom/1.0"]
      {:ok, pid} = Connection.start_link(opts)

      state = :sys.get_state(pid)
      assert state.user_agent == "Custom/1.0"
    end
  end

  describe "connect/3" do
    setup do
      unique_id = @account_id <> "_connect_#{System.unique_integer()}"
      {:ok, pid} = Connection.start_link(account_id: unique_id)
      {:ok, account_id: unique_id, pid: pid}
    end

    test "returns error when already connecting/connected", %{account_id: account_id, pid: pid} do
      :sys.replace_state(pid, fn state -> %{state | state: :connecting} end)

      session = %Session{
        uid: "123",
        secret_key: "key",
        ws_endpoints: ["wss://example.com/ws"]
      }

      assert {:error, :already_connected} = Connection.connect(account_id, session)
    end
  end

  describe "disconnect/1" do
    setup do
      unique_id = @account_id <> "_disconnect_#{System.unique_integer()}"
      {:ok, pid} = Connection.start_link(account_id: unique_id)
      {:ok, account_id: unique_id, pid: pid}
    end

    test "returns to disconnected state", %{account_id: account_id, pid: pid} do
      :sys.replace_state(pid, fn state -> %{state | state: :ready, cipher_key: "key123"} end)

      assert :ok = Connection.disconnect(account_id)

      state = :sys.get_state(pid)
      assert state.state == :disconnected
      assert state.cipher_key == nil
      assert state.conn == nil
    end

    test "clears ping timer", %{account_id: account_id, pid: pid} do
      timer_ref = Process.send_after(self(), :never, 100_000)

      :sys.replace_state(pid, fn state ->
        %{state | state: :ready, ping_timer: timer_ref}
      end)

      Connection.disconnect(account_id)
      state = :sys.get_state(pid)
      assert state.ping_timer == nil
    end
  end

  describe "send_frame/2" do
    setup do
      unique_id = @account_id <> "_send_#{System.unique_integer()}"
      {:ok, pid} = Connection.start_link(account_id: unique_id)
      {:ok, account_id: unique_id, pid: pid}
    end

    test "returns error when not ready", %{account_id: account_id} do
      frame = <<1, 0, 0, 1>> <> "{}"
      assert {:error, :not_ready} = Connection.send_frame(account_id, frame)
    end
  end

  describe "request_old_messages/3" do
    setup do
      unique_id = @account_id <> "_msg_#{System.unique_integer()}"
      {:ok, pid} = Connection.start_link(account_id: unique_id)
      {:ok, account_id: unique_id, pid: pid}
    end

    test "returns error when not ready", %{account_id: account_id} do
      assert {:error, :not_ready} = Connection.request_old_messages(account_id, :user)
    end
  end

  describe "request_old_reactions/3" do
    setup do
      unique_id = @account_id <> "_react_#{System.unique_integer()}"
      {:ok, pid} = Connection.start_link(account_id: unique_id)
      {:ok, account_id: unique_id, pid: pid}
    end

    test "returns error when not ready", %{account_id: account_id} do
      assert {:error, :not_ready} = Connection.request_old_reactions(account_id, :group)
    end
  end

  describe "state struct" do
    test "has correct default values" do
      state = %Connection{}

      assert state.account_id == nil
      assert state.session == nil
      assert state.conn == nil
      assert state.websocket == nil
      assert state.ref == nil
      assert state.cipher_key == nil
      assert state.ping_timer == nil
      assert state.user_agent == nil
      assert state.endpoint_index == 0
      assert state.retry_counters == %{}
      assert state.state == :disconnected
      assert state.request_id == 0
    end
  end
end
