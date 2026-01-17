defmodule ZcaEx.Account.Runtime do
  @moduledoc """
  Orchestrates "always-on" account lifecycle - auto-login, auto-connect WS, handle reconnection on session expiry.

  ## State Machine Phases

  - `:idle` - initial state, waiting for reconcile
  - `:logging_in` - login in progress
  - `:login_backoff` - waiting to retry login after failure
  - `:logged_in` - login succeeded, may or may not have WS
  - `:ws_connecting` - WS connection in progress
  - `:ws_ready` - fully connected and ready
  - `:stopped` - auto-features disabled

  ## Configuration

      %{
        auto_login: true,
        ws: %{auto_connect: true, reconnect: true},
        login: %{retry: %{enabled: true, min_ms: 1000, max_ms: 30_000, factor: 2.0, jitter: 0.2}}
      }

  """
  use GenServer
  require Logger

  alias ZcaEx.Account.Manager
  alias ZcaEx.Events
  alias ZcaEx.Events.{Dispatcher, Topic}
  alias ZcaEx.WS.Connection

  @default_config %{
    auto_login: true,
    ws: %{auto_connect: true, reconnect: true},
    login: %{retry: %{enabled: true, min_ms: 1000, max_ms: 30_000, factor: 2.0, jitter: 0.2}}
  }

  @session_expiry_reasons [:duplicate, :invalid_cipher_key, :auth_error, :session_expired]

  # WS close codes that indicate auth/session issues
  @auth_close_codes [4001, 4002, 4003]

  defstruct [
    :account_id,
    :config,
    :login_backoff_timer,
    :login_attempt,
    phase: :idle
  ]

  @type phase ::
          :idle
          | :logging_in
          | :login_backoff
          | :logged_in
          | :ws_connecting
          | :ws_ready
          | :stopped

  @type config :: %{
          auto_login: boolean(),
          ws: %{auto_connect: boolean(), reconnect: boolean()},
          login: %{
            retry: %{
              enabled: boolean(),
              min_ms: non_neg_integer(),
              max_ms: non_neg_integer(),
              factor: float(),
              jitter: float()
            }
          }
        }

  @type t :: %__MODULE__{
          account_id: String.t(),
          config: config(),
          login_backoff_timer: reference() | nil,
          login_attempt: non_neg_integer() | nil,
          phase: phase()
        }

  ## Public API

  @doc "Start the Runtime GenServer"
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    GenServer.start_link(__MODULE__, opts, name: via(account_id))
  end

  @doc "Get current status"
  @spec status(String.t()) :: {:ok, %{phase: phase(), config: config()}}
  def status(account_id) do
    GenServer.call(via(account_id), :status)
  end

  @doc "Merge new config and trigger reconcile"
  @spec configure(String.t(), keyword() | map()) :: :ok
  def configure(account_id, opts) do
    GenServer.call(via(account_id), {:configure, opts})
  end

  @doc "Force a reconcile cycle"
  @spec reconcile(String.t()) :: :ok
  def reconcile(account_id) do
    GenServer.cast(via(account_id), :reconcile)
  end

  @doc "Disable auto-login and auto-connect (does not terminate process)"
  @spec stop(String.t()) :: :ok
  def stop(account_id) do
    GenServer.call(via(account_id), :stop)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    runtime_config = Keyword.get(opts, :runtime, %{})
    config = deep_merge(@default_config, normalize_config(runtime_config))

    subscribe_to_lifecycle_events(account_id)

    state = %__MODULE__{
      account_id: account_id,
      config: config,
      phase: :idle,
      login_attempt: 0
    }

    Dispatcher.dispatch(account_id, :runtime_started, %{config: config})
    schedule_reconcile(0)

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, {:ok, %{phase: state.phase, config: state.config}}, state}
  end

  def handle_call({:configure, opts}, _from, state) do
    new_config = deep_merge(state.config, normalize_config(opts))
    new_state = %{state | config: new_config}
    schedule_reconcile(0)
    {:reply, :ok, new_state}
  end

  def handle_call(:stop, _from, state) do
    new_state = cancel_backoff_timer(state)
    {:reply, :ok, %{new_state | phase: :stopped}}
  end

  @impl true
  def handle_cast(:reconcile, state) do
    {:noreply, do_reconcile(state)}
  end

  @impl true
  def handle_info(:reconcile, state) do
    {:noreply, do_reconcile(state)}
  end

  def handle_info(:login_backoff_retry, %{phase: :login_backoff} = state) do
    new_state = %{state | login_backoff_timer: nil}
    {:noreply, do_reconcile(new_state)}
  end

  def handle_info(:login_backoff_retry, state) do
    {:noreply, state}
  end

  def handle_info({:zca_event, topic, event}, state) do
    {:noreply, handle_lifecycle_event(topic, event, state)}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Functions

  defp via(account_id), do: {:via, Registry, {ZcaEx.Registry, {:runtime, account_id}}}

  defp subscribe_to_lifecycle_events(account_id) do
    events = [:ready, :connected, :disconnected, :closed, :error]

    Enum.each(events, fn event_type ->
      topic = Topic.build(account_id, event_type)
      Events.subscribe(topic)
    end)
  end

  defp schedule_reconcile(delay_ms) do
    Process.send_after(self(), :reconcile, delay_ms)
  end

  defp do_reconcile(%{phase: :stopped} = state), do: state

  defp do_reconcile(%{phase: :logging_in} = state), do: state

  defp do_reconcile(%{phase: :login_backoff} = state) do
    # Check if config changed to disable auto-login or retry
    if not state.config.auto_login or not state.config.login.retry.enabled do
      state
      |> cancel_backoff_timer()
      |> Map.put(:phase, :idle)
    else
      state
    end
  end

  defp do_reconcile(%{phase: :ws_connecting} = state), do: state

  defp do_reconcile(state) do
    case safe_manager_call(:get_state, state.account_id) do
      {:ok, :logged_in} ->
        handle_logged_in_state(state)

      {:ok, _} ->
        maybe_trigger_login(state)

      {:error, :noproc} ->
        # Manager is restarting, go idle and retry shortly
        schedule_reconcile(100)
        %{state | phase: :idle}
    end
  end

  defp handle_logged_in_state(state) do
    state = %{state | phase: :logged_in, login_attempt: 0}

    if state.config.ws.auto_connect do
      trigger_ws_connect(state)
    else
      state
    end
  end

  defp maybe_trigger_login(state) do
    if state.config.auto_login do
      trigger_login(state)
    else
      %{state | phase: :idle}
    end
  end

  defp trigger_login(state) do
    Logger.debug("Runtime[#{state.account_id}] starting login attempt #{state.login_attempt + 1}")
    Dispatcher.dispatch(state.account_id, :login_start, %{attempt: state.login_attempt + 1})

    new_state = %{state | phase: :logging_in, login_attempt: state.login_attempt + 1}

    case safe_manager_call(:login, state.account_id) do
      {:ok, {:ok, _session}} ->
        Logger.debug("Runtime[#{state.account_id}] login succeeded")
        Dispatcher.dispatch(state.account_id, :login_ok, %{})
        handle_logged_in_state(%{new_state | phase: :logged_in, login_attempt: 0})

      {:ok, {:error, reason}} ->
        Logger.warning("Runtime[#{state.account_id}] login failed: #{inspect(reason)}")
        Dispatcher.dispatch(state.account_id, :login_error, %{reason: reason})
        handle_login_failure(new_state, reason)

      {:error, :noproc} ->
        # Manager is restarting, go idle and retry shortly
        schedule_reconcile(100)
        %{state | phase: :idle}
    end
  end

  defp handle_login_failure(state, _reason) do
    retry_config = state.config.login.retry

    if retry_config.enabled do
      delay = calculate_backoff(state.login_attempt, retry_config)
      Logger.debug("Runtime[#{state.account_id}] scheduling login retry in #{delay}ms")
      timer = Process.send_after(self(), :login_backoff_retry, delay)
      %{state | phase: :login_backoff, login_backoff_timer: timer}
    else
      %{state | phase: :idle}
    end
  end

  defp calculate_backoff(attempt, config) do
    base_delay = config.min_ms * :math.pow(config.factor, attempt - 1)
    capped_delay = min(base_delay, config.max_ms)
    jitter_range = capped_delay * config.jitter
    jitter = :rand.uniform() * 2 * jitter_range - jitter_range
    max(round(capped_delay + jitter), config.min_ms)
  end

  defp trigger_ws_connect(state) do
    case safe_manager_call(:get_session, state.account_id) do
      {:ok, session} when not is_nil(session) ->
        Logger.debug("Runtime[#{state.account_id}] starting WS connection")
        Dispatcher.dispatch(state.account_id, :ws_autoconnect_start, %{})

        reconnect = state.config.ws.reconnect

        case Connection.connect(state.account_id, session, reconnect: reconnect) do
          :ok ->
            %{state | phase: :ws_connecting}

          {:error, :already_connected} ->
            %{state | phase: :ws_ready}

          {:error, reason} ->
            Logger.warning("Runtime[#{state.account_id}] WS connect failed: #{inspect(reason)}")
            # Schedule retry after short delay
            schedule_reconcile(500)
            %{state | phase: :logged_in}
        end

      {:ok, nil} ->
        Logger.warning("Runtime[#{state.account_id}] no session available for WS connect")
        state

      {:error, :noproc} ->
        # Manager is restarting, go idle and retry shortly
        schedule_reconcile(100)
        %{state | phase: :idle}
    end
  end

  defp handle_lifecycle_event(_topic, _event, %{phase: :stopped} = state) do
    # Stopped is sticky - ignore lifecycle events
    state
  end

  defp handle_lifecycle_event(topic, event, state) do
    case Topic.parse(topic) do
      {:ok, %{event_type: :ready}} ->
        Logger.debug("Runtime[#{state.account_id}] WS ready")
        %{state | phase: :ws_ready}

      {:ok, %{event_type: :connected}} ->
        Logger.debug("Runtime[#{state.account_id}] WS connected")
        # Only transition to :ws_connecting if not already :ws_ready
        if state.phase == :ws_ready do
          state
        else
          %{state | phase: :ws_connecting}
        end

      {:ok, %{event_type: event_type}} when event_type in [:disconnected, :closed, :error] ->
        handle_ws_disconnect(event_type, event, state)

      _ ->
        state
    end
  end

  defp handle_ws_disconnect(event_type, event, state) do
    Logger.debug("Runtime[#{state.account_id}] WS #{event_type}: #{inspect(event)}")

    reason = extract_disconnect_reason(event)

    if session_expired?(reason) do
      Logger.info("Runtime[#{state.account_id}] session expired (#{inspect(reason)}), re-login")
      Dispatcher.dispatch(state.account_id, :session_expired, %{reason: reason})
      # Bypass do_reconcile and force re-login directly since Manager may still report :logged_in
      trigger_login(%{state | phase: :idle, login_attempt: 0})
    else
      new_state = %{state | phase: :logged_in}

      if state.config.ws.auto_connect and state.config.ws.reconnect do
        schedule_reconcile(100)
      end

      new_state
    end
  end

  defp extract_disconnect_reason(%{reason: reason}), do: reason
  defp extract_disconnect_reason(%{code: code}), do: map_close_code(code)
  defp extract_disconnect_reason(reason) when is_atom(reason), do: reason
  defp extract_disconnect_reason(code) when is_integer(code), do: map_close_code(code)
  defp extract_disconnect_reason({:auth_error, _}), do: :auth_error
  defp extract_disconnect_reason({reason, _}) when is_atom(reason), do: reason
  defp extract_disconnect_reason(_), do: :unknown

  defp map_close_code(code) when code in @auth_close_codes, do: :auth_error
  defp map_close_code(code), do: code

  defp session_expired?(reason) when is_atom(reason), do: reason in @session_expiry_reasons
  defp session_expired?(code) when is_integer(code), do: code in @auth_close_codes
  defp session_expired?(_), do: false

  defp safe_manager_call(:get_state, account_id) do
    {:ok, Manager.get_state(account_id)}
  catch
    :exit, {:noproc, _} -> {:error, :noproc}
    :exit, _ -> {:error, :noproc}
  end

  defp safe_manager_call(:login, account_id) do
    {:ok, Manager.login(account_id)}
  catch
    :exit, {:noproc, _} -> {:error, :noproc}
    :exit, _ -> {:error, :noproc}
  end

  defp safe_manager_call(:get_session, account_id) do
    {:ok, Manager.get_session(account_id)}
  catch
    :exit, {:noproc, _} -> {:error, :noproc}
    :exit, _ -> {:error, :noproc}
  end

  defp cancel_backoff_timer(%{login_backoff_timer: nil} = state), do: state

  defp cancel_backoff_timer(%{login_backoff_timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | login_backoff_timer: nil}
  end

  defp normalize_config(opts) when is_list(opts), do: Map.new(opts)
  defp normalize_config(opts) when is_map(opts), do: opts

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn
      _key, left_val, right_val when is_map(left_val) and is_map(right_val) ->
        deep_merge(left_val, right_val)

      _key, _left_val, right_val ->
        right_val
    end)
  end
end
