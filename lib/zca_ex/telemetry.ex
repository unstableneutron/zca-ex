defmodule ZcaEx.Telemetry do
  @moduledoc """
  Standardized telemetry events for ZcaEx.

  ## Events

  All events are prefixed with `[:zca_ex]` and follow telemetry conventions.

  ### WebSocket Events

  * `[:zca_ex, :ws, :connect, :start]` - WS connection initiated
    * Measurements: `%{system_time: integer}`
    * Metadata: `%{account_id: term, endpoint_host: binary}`

  * `[:zca_ex, :ws, :connect, :stop]` - WS connection completed
    * Measurements: `%{duration: integer}` (native time units)
    * Metadata: `%{account_id: term, result: :ok | :error}`

  * `[:zca_ex, :ws, :connect, :exception]` - WS connection failed with exception
    * Measurements: `%{duration: integer}`
    * Metadata: `%{account_id: term, kind: atom, reason: term, stacktrace: list}`

  * `[:zca_ex, :ws, :disconnect]` - WS connection closed
    * Measurements: `%{system_time: integer}`
    * Metadata: `%{account_id: term, reason: atom}`

  * `[:zca_ex, :ws, :reconnect]` - Reconnection attempt
    * Measurements: `%{system_time: integer, attempt: pos_integer, delay_ms: non_neg_integer}`
    * Metadata: `%{account_id: term, endpoint_index: non_neg_integer}`

  * `[:zca_ex, :ws, :message, :received]` - Incoming WS message
    * Measurements: `%{system_time: integer, bytes: non_neg_integer}`
    * Metadata: `%{account_id: term, message_type: atom}`

  * `[:zca_ex, :ws, :message, :sent]` - Outgoing WS message
    * Measurements: `%{system_time: integer, bytes: non_neg_integer}`
    * Metadata: `%{account_id: term}`

  ### HTTP Events

  * `[:zca_ex, :http, :request, :start]` - HTTP request initiated
    * Measurements: `%{system_time: integer}`
    * Metadata: `%{account_id: term, method: atom, endpoint_host: binary}`

  * `[:zca_ex, :http, :request, :stop]` - HTTP request completed
    * Measurements: `%{duration: integer}`
    * Metadata: `%{account_id: term, status_code: integer}`

  * `[:zca_ex, :http, :request, :exception]` - HTTP request failed with exception
    * Measurements: `%{duration: integer}`
    * Metadata: `%{account_id: term, kind: atom, reason: term, stacktrace: list}`

  ### Account Events

  * `[:zca_ex, :account, :started]` - Account process started
    * Measurements: `%{system_time: integer}`
    * Metadata: `%{account_id: term}`

  * `[:zca_ex, :account, :stopped]` - Account process stopped
    * Measurements: `%{system_time: integer}`
    * Metadata: `%{account_id: term}`

  ### Error Events

  * `[:zca_ex, :error]` - General error event
    * Measurements: `%{system_time: integer}`
    * Metadata: `%{account_id: term, category: atom, reason: atom}`

  ## Metadata Guidelines

  To ensure metrics remain useful and cardinality stays bounded:

  * **Always include**: `account_id`, timestamps (via `system_time` or `monotonic_time`)
  * **Avoid high-cardinality values**:
    - Don't include full URLs with query parameters
    - Don't include raw error messages or payloads
    - Don't include request/response bodies
  * **Use stable tags**: `endpoint_host`, `status_code`, `message_type`, `category`

  ## Usage

  Attach handlers in your application startup:

      :telemetry.attach_many(
        "my-handler",
        [
          [:zca_ex, :ws, :connect, :stop],
          [:zca_ex, :http, :request, :stop],
          [:zca_ex, :error]
        ],
        &MyModule.handle_event/4,
        nil
      )

  """

  @type event_name :: [atom(), ...]
  @type measurements :: map()
  @type metadata :: map()

  @doc """
  Wraps `:telemetry.span/3` with the given event prefix.

  The function will emit `[prefix, :start]` before execution and
  `[prefix, :stop]` or `[prefix, :exception]` after.
  """
  @spec span(event_name(), metadata(), (-> result)) :: result when result: term()
  def span(event_prefix, meta, fun) when is_list(event_prefix) and is_function(fun, 0) do
    :telemetry.span(event_prefix, meta, fn ->
      result = fun.()
      {result, %{}}
    end)
  end

  @doc """
  Emits a telemetry event with the given name, measurements, and metadata.

  Wraps `:telemetry.execute/3`.
  """
  @spec event(event_name(), measurements(), metadata()) :: :ok
  def event(event_name, measurements, meta) when is_list(event_name) do
    :telemetry.execute(event_name, measurements, meta)
  end

  @doc """
  Emits `[:zca_ex, :ws, :connect, :start]` event.
  """
  @spec ws_connect_start(term(), binary()) :: :ok
  def ws_connect_start(account_id, endpoint) do
    event(
      [:zca_ex, :ws, :connect, :start],
      %{system_time: System.system_time()},
      %{account_id: account_id, endpoint_host: extract_host(endpoint)}
    )
  end

  @doc """
  Emits `[:zca_ex, :ws, :connect, :stop]` event.
  """
  @spec ws_connect_stop(term(), non_neg_integer(), :ok | :error) :: :ok
  def ws_connect_stop(account_id, duration_ns, result) do
    event(
      [:zca_ex, :ws, :connect, :stop],
      %{duration: duration_ns},
      %{account_id: account_id, result: result}
    )
  end

  @doc """
  Emits `[:zca_ex, :ws, :disconnect]` event.
  """
  @spec ws_disconnect(term(), atom()) :: :ok
  def ws_disconnect(account_id, reason) do
    event(
      [:zca_ex, :ws, :disconnect],
      %{system_time: System.system_time()},
      %{account_id: account_id, reason: reason}
    )
  end

  @doc """
  Emits `[:zca_ex, :ws, :reconnect]` event.
  """
  @spec ws_reconnect(term(), pos_integer(), non_neg_integer(), non_neg_integer()) :: :ok
  def ws_reconnect(account_id, attempt, endpoint_index, delay_ms) do
    event(
      [:zca_ex, :ws, :reconnect],
      %{system_time: System.system_time(), attempt: attempt, delay_ms: delay_ms},
      %{account_id: account_id, endpoint_index: endpoint_index}
    )
  end

  @doc """
  Emits `[:zca_ex, :ws, :message, :received]` event.
  """
  @spec ws_message_received(term(), non_neg_integer(), atom()) :: :ok
  def ws_message_received(account_id, bytes, message_type) do
    event(
      [:zca_ex, :ws, :message, :received],
      %{system_time: System.system_time(), bytes: bytes},
      %{account_id: account_id, message_type: message_type}
    )
  end

  @doc """
  Emits `[:zca_ex, :ws, :message, :sent]` event.
  """
  @spec ws_message_sent(term(), non_neg_integer()) :: :ok
  def ws_message_sent(account_id, bytes) do
    event(
      [:zca_ex, :ws, :message, :sent],
      %{system_time: System.system_time(), bytes: bytes},
      %{account_id: account_id}
    )
  end

  @doc """
  Emits `[:zca_ex, :http, :request, :start]` event.
  """
  @spec http_request_start(term(), atom(), binary()) :: :ok
  def http_request_start(account_id, method, url) do
    event(
      [:zca_ex, :http, :request, :start],
      %{system_time: System.system_time()},
      %{account_id: account_id, method: method, endpoint_host: extract_host(url)}
    )
  end

  @doc """
  Emits `[:zca_ex, :http, :request, :stop]` event.
  """
  @spec http_request_stop(term(), non_neg_integer(), integer()) :: :ok
  def http_request_stop(account_id, duration_ns, status) do
    event(
      [:zca_ex, :http, :request, :stop],
      %{duration: duration_ns},
      %{account_id: account_id, status_code: status}
    )
  end

  @doc """
  Emits `[:zca_ex, :account, :started]` event.
  """
  @spec account_started(term()) :: :ok
  def account_started(account_id) do
    event(
      [:zca_ex, :account, :started],
      %{system_time: System.system_time()},
      %{account_id: account_id}
    )
  end

  @doc """
  Emits `[:zca_ex, :account, :stopped]` event.
  """
  @spec account_stopped(term()) :: :ok
  def account_stopped(account_id) do
    event(
      [:zca_ex, :account, :stopped],
      %{system_time: System.system_time()},
      %{account_id: account_id}
    )
  end

  @doc """
  Emits `[:zca_ex, :error]` event.
  """
  @spec error(term(), atom(), atom()) :: :ok
  def error(account_id, category, reason) do
    event(
      [:zca_ex, :error],
      %{system_time: System.system_time()},
      %{account_id: account_id, category: category, reason: reason}
    )
  end

  defp extract_host(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> "unknown"
    end
  end

  defp extract_host(_), do: "unknown"
end
