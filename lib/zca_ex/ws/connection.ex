defmodule ZcaEx.WS.Connection do
  @moduledoc """
  WebSocket connection GenServer for Zalo real-time events.

  Manages the WebSocket connection lifecycle using mint_web_socket.
  States: :disconnected -> :connecting -> :connected -> :ready
          :backing_off (waiting to reconnect)
  """
  use GenServer
  require Logger

  alias ZcaEx.Account.Session
  alias ZcaEx.CookieJar
  alias ZcaEx.Crypto.AesGcm
  alias ZcaEx.Error
  alias ZcaEx.Events.Dispatcher
  alias ZcaEx.Model.{DeliveredMessage, Message, Reaction, SeenMessage, Typing, Undo}
  alias ZcaEx.Telemetry
  alias ZcaEx.WS.{ControlParser, Frame, RetryPolicy, Router}

  @ping_interval_ms 30_000
  @default_user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  defstruct [
    :account_id,
    :session,
    :conn,
    :websocket,
    :ref,
    :cipher_key,
    :ping_timer,
    :user_agent,
    :upgrade_status,
    :retry_policy,
    :reconnect_reason,
    :connect_start_time,
    endpoint_index: 0,
    retry_counters: %{},
    state: :disconnected,
    request_id: 0,
    reconnect_enabled: true
  ]

  @type t :: %__MODULE__{
          account_id: String.t(),
          session: Session.t() | nil,
          conn: Mint.HTTP.t() | nil,
          websocket: Mint.WebSocket.t() | nil,
          ref: reference() | nil,
          cipher_key: binary() | nil,
          ping_timer: reference() | nil,
          user_agent: String.t() | nil,
          upgrade_status: non_neg_integer() | nil,
          endpoint_index: non_neg_integer(),
          retry_counters: map(),
          state: :disconnected | :connecting | :connected | :ready | :backing_off,
          request_id: non_neg_integer(),
          retry_policy: RetryPolicy.t() | nil,
          reconnect_enabled: boolean(),
          reconnect_reason: term() | nil,
          connect_start_time: integer() | nil
        }

  ## Public API

  @doc "Start the WebSocket connection GenServer"
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    GenServer.start_link(__MODULE__, opts, name: via(account_id))
  end

  @doc "Initiate WebSocket connection with the given session"
  @spec connect(String.t(), Session.t(), keyword()) :: :ok | {:error, term()}
  def connect(account_id, session, opts \\ []) do
    GenServer.call(via(account_id), {:connect, session, opts})
  end

  @doc "Disconnect the WebSocket connection"
  @spec disconnect(String.t()) :: :ok
  def disconnect(account_id) do
    GenServer.call(via(account_id), :disconnect)
  end

  @doc "Explicitly disconnect without reconnection"
  @spec explicit_disconnect(String.t()) :: :ok
  def explicit_disconnect(account_id) do
    GenServer.call(via(account_id), :explicit_disconnect)
  end

  @doc "Send a raw binary frame"
  @spec send_frame(String.t(), binary()) :: :ok | {:error, term()}
  def send_frame(account_id, frame) when is_binary(frame) do
    GenServer.call(via(account_id), {:send_frame, frame})
  end

  @doc "Request old messages for a thread type"
  @spec request_old_messages(String.t(), :user | :group, String.t() | integer() | nil) ::
          :ok | {:error, term()}
  def request_old_messages(account_id, thread_type, last_id \\ nil) do
    frame = Frame.old_messages_frame(thread_type, last_id)
    send_frame(account_id, frame)
  end

  @doc "Request old reactions for a thread type"
  @spec request_old_reactions(String.t(), :user | :group, String.t() | integer() | nil) ::
          :ok | {:error, term()}
  def request_old_reactions(account_id, thread_type, last_id \\ nil) do
    frame = Frame.old_reactions_frame(thread_type, last_id)
    send_frame(account_id, frame)
  end

  @doc "Get the current connection status"
  @spec connection_status(String.t()) ::
          {:ok, %{state: atom(), connected_at: DateTime.t() | nil}} | {:error, :not_found}
  def connection_status(account_id) do
    try do
      GenServer.call(via(account_id), :connection_status)
    catch
      :exit, {:noproc, _} -> {:error, :not_found}
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    user_agent = Keyword.get(opts, :user_agent, @default_user_agent)

    {:ok,
     %__MODULE__{
       account_id: account_id,
       user_agent: user_agent,
       state: :disconnected
     }}
  end

  @impl true
  def handle_call({:connect, session, opts}, _from, %{state: :disconnected} = state) do
    user_agent = Keyword.get(opts, :user_agent, state.user_agent)
    reconnect_enabled = Keyword.get(opts, :reconnect, true)

    state = %{
      state
      | session: session,
        user_agent: user_agent,
        state: :connecting,
        reconnect_enabled: reconnect_enabled
    }

    case do_connect(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, %{state | state: :disconnected}}
    end
  end

  def handle_call({:connect, _session, _opts}, _from, state) do
    {:reply, {:error, :already_connected}, state}
  end

  def handle_call(:disconnect, _from, state) do
    new_state = do_disconnect(state, :normal)
    {:reply, :ok, new_state}
  end

  def handle_call(:explicit_disconnect, _from, state) do
    new_state = %{state | reconnect_enabled: false}
    new_state = do_disconnect(new_state, :explicit)
    {:reply, :ok, new_state}
  end

  def handle_call({:send_frame, frame}, _from, %{state: :ready} = state) do
    case do_send_frame(state, frame) do
      {:ok, new_state} ->
        Telemetry.ws_message_sent(state.account_id, byte_size(frame))
        {:reply, :ok, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call({:send_frame, _frame}, _from, state) do
    {:reply, {:error, :not_ready}, state}
  end

  def handle_call(:connection_status, _from, state) do
    status = %{
      state: state.state,
      connected_at: nil
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_info(:ping, %{state: :ready} = state) do
    frame = Frame.ping_frame()

    case do_send_frame(state, frame) do
      {:ok, new_state} ->
        {:noreply, schedule_ping(new_state)}

      {:error, _reason, new_state} ->
        {:noreply, new_state}
    end
  end

  def handle_info(:ping, state) do
    {:noreply, state}
  end

  def handle_info(:reconnect, %{state: :backing_off} = state) do
    case do_connect(state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, reason} ->
        error = Error.normalize(reason)
        handle_reconnect_failure(error, state)
    end
  end

  def handle_info(:reconnect, state) do
    {:noreply, state}
  end

  def handle_info(message, %{conn: conn} = state) when conn != nil do
    case Mint.WebSocket.stream(conn, message) do
      {:ok, conn, responses} ->
        state = %{state | conn: conn}
        {:noreply, handle_responses(responses, state)}

      {:error, conn, reason, _responses} ->
        Logger.warning("WebSocket stream error: #{inspect(reason)}")
        new_state = %{state | conn: conn}
        {:noreply, do_disconnect(new_state, :stream_error)}

      :unknown ->
        {:noreply, state}
    end
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    do_disconnect(state, :terminate)
    :ok
  end

  ## Private Functions

  defp via(account_id), do: {:via, Registry, {ZcaEx.Registry, {:ws, account_id}}}

  defp do_connect(state) do
    %{session: session, account_id: account_id, user_agent: user_agent} = state

    idx =
      if state.retry_policy do
        state.retry_policy.endpoint_index
      else
        state.endpoint_index
      end

    endpoint = Enum.at(session.ws_endpoints, idx) || hd(session.ws_endpoints)

    start_time = System.monotonic_time()
    Telemetry.ws_connect_start(account_id, endpoint)

    uri = build_ws_uri(endpoint, session)

    cookies = CookieJar.get_cookie_string(account_id, "https://chat.zalo.me")

    headers = [
      {"accept-encoding", "gzip, deflate, br, zstd"},
      {"accept-language", "en-US,en;q=0.9"},
      {"cache-control", "no-cache"},
      {"host", uri.host},
      {"origin", "https://chat.zalo.me"},
      {"pragma", "no-cache"},
      {"user-agent", user_agent},
      {"cookie", cookies}
    ]

    http_scheme = if uri.scheme == "wss", do: :https, else: :http
    ws_scheme = if uri.scheme == "wss", do: :wss, else: :ws
    port = uri.port || if(http_scheme == :https, do: 443, else: 80)

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme, uri.host, port, protocols: [:http1]),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(ws_scheme, conn, ws_path(uri), headers) do
      {:ok, %{state | conn: conn, ref: ref, state: :connecting, connect_start_time: start_time}}
    end
  end

  defp build_ws_uri(endpoint, session) do
    timestamp = System.system_time(:millisecond)

    query =
      URI.encode_query(%{
        "t" => timestamp,
        "zpw_ver" => session.api_version,
        "zpw_type" => session.api_type
      })

    base_uri = URI.parse(endpoint)
    existing_query = base_uri.query

    full_query =
      if existing_query do
        "#{existing_query}&#{query}"
      else
        query
      end

    %{base_uri | query: full_query}
  end

  defp ws_path(uri) do
    path = uri.path || "/"

    if uri.query do
      "#{path}?#{uri.query}"
    else
      path
    end
  end

  defp do_disconnect(state, reason) do
    if state.ping_timer, do: Process.cancel_timer(state.ping_timer)

    if state.conn do
      _ = Mint.HTTP.close(state.conn)
    end

    Telemetry.ws_disconnect(state.account_id, disconnect_reason_atom(reason))
    Dispatcher.dispatch_lifecycle(state.account_id, :disconnected, %{})

    base_state = %{
      state
      | conn: nil,
        websocket: nil,
        ref: nil,
        cipher_key: nil,
        ping_timer: nil,
        reconnect_reason: reason
    }

    maybe_schedule_reconnect(base_state, reason)
  end

  defp disconnect_reason_atom(reason) when is_atom(reason), do: reason
  defp disconnect_reason_atom(_), do: :unknown

  defp maybe_schedule_reconnect(state, reason) do
    should_reconnect =
      state.reconnect_enabled and
        reason not in [:explicit, :normal, :duplicate] and
        state.session != nil

    if should_reconnect do
      schedule_reconnect(state)
    else
      %{state | state: :disconnected, retry_policy: nil}
    end
  end

  defp schedule_reconnect(state) do
    total_endpoints = length(state.session.ws_endpoints)

    policy =
      state.retry_policy ||
        RetryPolicy.new(total_endpoints)

    case RetryPolicy.next_delay(policy) do
      {:retry, delay, new_policy} ->
        Telemetry.ws_reconnect(
          state.account_id,
          new_policy.current_attempt,
          new_policy.endpoint_index,
          delay
        )

        Process.send_after(self(), :reconnect, delay)

        %{state | state: :backing_off, retry_policy: new_policy}

      {:halt, halt_reason} ->
        Logger.warning("Reconnection halted: #{halt_reason}")
        Telemetry.error(state.account_id, :websocket, halt_reason)
        %{state | state: :disconnected, retry_policy: nil}
    end
  end

  defp handle_reconnect_failure(error, state) do
    if Error.retryable?(error) do
      {:noreply, schedule_reconnect(state)}
    else
      Logger.warning("Non-retryable error during reconnect: #{inspect(error)}")
      Telemetry.error(state.account_id, :websocket, :non_retryable)
      {:noreply, %{state | state: :disconnected, retry_policy: nil}}
    end
  end

  defp handle_responses(responses, state) do
    Enum.reduce(responses, state, fn response, acc ->
      handle_response(response, acc)
    end)
  end

  defp handle_response({:status, ref, status}, %{ref: ref} = state) do
    if status != 101 do
      Logger.warning("WebSocket upgrade failed with status #{status}")
    end

    %{state | upgrade_status: status}
  end

  defp handle_response({:headers, ref, headers}, %{ref: ref, conn: conn} = state) do
    case Mint.WebSocket.new(conn, ref, status(state), headers) do
      {:ok, conn, websocket} ->
        Dispatcher.dispatch_lifecycle(state.account_id, :connected, %{})
        %{state | conn: conn, websocket: websocket, state: :connected}

      {:error, conn, reason} ->
        Logger.error("WebSocket handshake failed: #{inspect(reason)}")
        do_disconnect(%{state | conn: conn}, :handshake_failed)
    end
  end

  defp handle_response({:data, ref, data}, %{ref: ref, websocket: ws} = state) when ws != nil do
    case Mint.WebSocket.decode(ws, data) do
      {:ok, websocket, frames} ->
        state = %{state | websocket: websocket}
        handle_ws_frames(frames, state)

      {:error, websocket, reason} ->
        Logger.warning("WebSocket decode error: #{inspect(reason)}")
        %{state | websocket: websocket}
    end
  end

  defp handle_response({:done, ref}, %{ref: ref} = state) do
    # For WebSocket connections, {:done, ref} means the HTTP upgrade response is complete,
    # NOT that the connection is closed. Only disconnect if the WebSocket wasn't established.
    if state.websocket == nil do
      Logger.warning("HTTP upgrade completed without establishing WebSocket")
      do_disconnect(state, :upgrade_failed)
    else
      # WebSocket established - this is normal, just continue
      Logger.debug("HTTP upgrade complete, WebSocket established")
      state
    end
  end

  defp handle_response({:error, ref, reason}, %{ref: ref} = state) do
    Logger.error("WebSocket error: #{inspect(reason)}")
    Dispatcher.dispatch_lifecycle(state.account_id, :error, %{reason: reason})
    do_disconnect(state, :error)
  end

  defp handle_response(_response, state), do: state

  defp status(%{upgrade_status: status}) when is_integer(status), do: status
  defp status(_state), do: 101

  defp handle_ws_frames(frames, state) do
    Enum.reduce(frames, state, fn frame, acc ->
      handle_ws_frame(frame, acc)
    end)
  end

  defp handle_ws_frame({:binary, data}, state) do
    Telemetry.ws_message_received(state.account_id, byte_size(data), :binary)

    case Frame.decode(data) do
      {:ok, header, payload} ->
        handle_decoded_frame(header, payload, state)

      {:error, reason} ->
        Logger.warning("Failed to decode frame: #{inspect(reason)}")
        state
    end
  end

  defp handle_ws_frame({:close, code, reason}, state) do
    Logger.info("WebSocket closed: code=#{code}, reason=#{reason}")
    Dispatcher.dispatch_lifecycle(state.account_id, :closed, %{code: code, reason: reason})
    do_disconnect(state, :closed)
  end

  defp handle_ws_frame({:ping, data}, state) do
    case Mint.WebSocket.encode(state.websocket, {:pong, data}) do
      {:ok, websocket, bytes} ->
        case Mint.WebSocket.stream_request_body(state.conn, state.ref, bytes) do
          {:ok, conn} -> %{state | conn: conn, websocket: websocket}
          {:error, conn, _} -> %{state | conn: conn, websocket: websocket}
        end

      {:error, websocket, _} ->
        %{state | websocket: websocket}
    end
  end

  defp handle_ws_frame({:pong, _data}, state) do
    state
  end

  defp handle_ws_frame(_frame, state), do: state

  defp handle_decoded_frame(header, payload, state) do
    {event_type, thread_type} = Router.route(header)

    case event_type do
      :cipher_key ->
        handle_cipher_key(payload, state)

      :ping ->
        state

      :duplicate ->
        Logger.warning("Duplicate connection detected, disconnecting")
        do_disconnect(state, :duplicate)

      :unknown ->
        Logger.debug("Unknown event: #{inspect(header)}")
        state

      _ ->
        dispatch_event(event_type, thread_type, payload, state)
    end
  end

  defp handle_cipher_key(%{"key" => key_b64}, state) do
    case Base.decode64(key_b64) do
      {:ok, key} when byte_size(key) in [16, 24, 32] ->
        Logger.debug("Received cipher key")
        Dispatcher.dispatch_lifecycle(state.account_id, :ready, %{})

        duration =
          if state.connect_start_time do
            System.monotonic_time() - state.connect_start_time
          else
            0
          end

        Telemetry.ws_connect_stop(state.account_id, duration, :ok)

        state
        |> Map.put(:cipher_key, key)
        |> Map.put(:state, :ready)
        |> Map.put(:retry_policy, nil)
        |> Map.put(:connect_start_time, nil)
        |> schedule_ping()

      _ ->
        Logger.warning("Invalid cipher key received")
        do_disconnect(state, :invalid_cipher_key)
    end
  end

  defp handle_cipher_key(_payload, state), do: state

  defp dispatch_event(:control, _thread_type, payload, state) do
    payload
    |> ControlParser.parse()
    |> Enum.each(fn {event_type, event_payload} ->
      Dispatcher.dispatch(state.account_id, event_type, event_payload)
    end)

    state
  end

  defp dispatch_event(:typing, _thread_type, payload, state) do
    processed_payload =
      if Router.needs_decryption?(:typing) do
        decrypt_event_data(payload, state.cipher_key)
      else
        payload
      end

    data = Map.get(processed_payload, "data")

    if is_map(data) do
      act = Map.get(data, "act", "typing")
      thread_type = typing_thread_type(processed_payload)
      model = Typing.from_ws_data(data, act)
      Dispatcher.dispatch(state.account_id, :typing, thread_type, model)
    else
      Logger.warning("Dropping :typing event: data not a map after decryption")
    end

    state
  end

  defp dispatch_event(:reaction, _thread_type, payload, state) do
    processed_payload =
      if Router.needs_decryption?(:reaction) do
        decrypt_event_data(payload, state.cipher_key)
      else
        payload
      end

    data = Map.get(processed_payload, "data")

    if is_map(data) do
      uid = state.session.uid

      reacts = Map.get(data, "reacts", [])

      Enum.each(reacts, fn react ->
        model = Reaction.from_ws_data(react, uid, :user)
        Dispatcher.dispatch(state.account_id, :reaction, :user, model)
      end)

      react_groups = Map.get(data, "reactGroups", [])

      Enum.each(react_groups, fn react_group ->
        model = Reaction.from_ws_data(react_group, uid, :group)
        Dispatcher.dispatch(state.account_id, :reaction, :group, model)
      end)
    else
      Logger.warning("Dropping :reaction event: data not a map after decryption")
    end

    state
  end

  defp dispatch_event(:message, thread_type, payload, state) do
    processed_payload =
      if Router.needs_decryption?(:message) do
        decrypt_event_data(payload, state.cipher_key)
      else
        payload
      end

    data = Map.get(processed_payload, "data")

    if is_map(data) do
      uid = state.session.uid

      if is_undo_message?(data) do
        model = Undo.from_ws_data(data, uid, thread_type)
        Dispatcher.dispatch(state.account_id, :undo, thread_type, model)
      else
        model = Message.from_ws_data(data, uid, thread_type)
        Dispatcher.dispatch(state.account_id, :message, thread_type, model)
      end
    else
      Logger.warning("Dropping :message event: data not a map after decryption")
    end

    state
  end

  defp dispatch_event(:seen_delivered, thread_type, payload, state) do
    processed_payload =
      if Router.needs_decryption?(:seen_delivered) do
        decrypt_event_data(payload, state.cipher_key)
      else
        payload
      end

    data = Map.get(processed_payload, "data")

    if is_map(data) do
      uid = state.session.uid

      if is_seen_event?(data) do
        model = SeenMessage.from_ws_data(data, uid, thread_type)
        Dispatcher.dispatch(state.account_id, :seen, thread_type, model)
      else
        model = DeliveredMessage.from_ws_data(data, uid, thread_type)
        Dispatcher.dispatch(state.account_id, :delivered, thread_type, model)
      end
    else
      Logger.warning("Dropping :seen_delivered event: data not a map after decryption")
    end

    state
  end

  defp dispatch_event(:old_reactions, thread_type, payload, state) do
    processed_payload =
      if Router.needs_decryption?(:old_reactions) do
        decrypt_event_data(payload, state.cipher_key)
      else
        payload
      end

    data = Map.get(processed_payload, "data")

    if is_map(data) do
      uid = state.session.uid

      raw_reacts =
        case thread_type do
          :group -> Map.get(data, "reactGroups", [])
          _ -> Map.get(data, "reacts", [])
        end

      if is_list(raw_reacts) do
        models = Enum.map(raw_reacts, &Reaction.from_ws_data(&1, uid, thread_type))

        Dispatcher.dispatch(state.account_id, :old_reactions, thread_type, models)

        Enum.each(models, fn model ->
          Dispatcher.dispatch(state.account_id, :reaction, thread_type, model)
        end)
      else
        Logger.warning("Dropping :old_reactions event: reacts/reactGroups not a list")
      end
    else
      Logger.warning("Dropping :old_reactions event: data not a map after decryption")
    end

    state
  end

  defp dispatch_event(:old_messages, thread_type, payload, state) do
    processed_payload =
      if Router.needs_decryption?(:old_messages) do
        decrypt_event_data(payload, state.cipher_key)
      else
        payload
      end

    data = Map.get(processed_payload, "data")

    if is_map(data) do
      uid = state.session.uid

      raw_msgs =
        case thread_type do
          :group -> Map.get(data, "groupMsgs", [])
          _ -> Map.get(data, "msgs", [])
        end

      if is_list(raw_msgs) do
        models = Enum.map(raw_msgs, &Message.from_ws_data(&1, uid, thread_type))

        Dispatcher.dispatch(state.account_id, :old_messages, thread_type, models)

        Enum.each(models, fn model ->
          Dispatcher.dispatch(state.account_id, :message, thread_type, model)
        end)
      else
        Logger.warning("Dropping :old_messages event: msgs/groupMsgs not a list")
      end
    else
      Logger.warning("Dropping :old_messages event: data not a map after decryption")
    end

    state
  end

  defp dispatch_event(event_type, thread_type, payload, state) do
    processed_payload =
      if Router.needs_decryption?(event_type) do
        decrypt_event_data(payload, state.cipher_key)
      else
        payload
      end

    if thread_type do
      Dispatcher.dispatch(state.account_id, event_type, thread_type, processed_payload)
    else
      Dispatcher.dispatch(state.account_id, event_type, processed_payload)
    end

    state
  end

  defp is_undo_message?(%{"content" => %{"deleteMsg" => _}}), do: true

  defp is_undo_message?(%{"content" => content}) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, %{"deleteMsg" => _}} -> true
      _ -> false
    end
  end

  defp is_undo_message?(_), do: false

  defp is_seen_event?(%{"seenUids" => uids}) when is_list(uids) and length(uids) > 0, do: true
  defp is_seen_event?(%{"idTo" => id_to}) when is_binary(id_to), do: true
  defp is_seen_event?(_), do: false

  defp typing_thread_type(%{"data" => %{"act" => "gtyping"}}), do: :group
  defp typing_thread_type(%{"data" => %{"act" => _}}), do: :user
  defp typing_thread_type(_), do: :user

  defp decrypt_event_data(payload, cipher_key) when is_binary(cipher_key) do
    encrypt_type = Map.get(payload, "encrypt", 0)

    case Map.get(payload, "data") do
      nil ->
        payload

      data when is_binary(data) and encrypt_type in [1, 2, 3] ->
        decrypt_and_decompress(data, cipher_key, encrypt_type, payload)

      _data ->
        payload
    end
  end

  defp decrypt_event_data(payload, _cipher_key), do: payload

  defp decrypt_and_decompress(data, cipher_key, encrypt_type, original_payload) do
    decoded_data = if encrypt_type == 2, do: URI.decode(data), else: data

    with {:ok, encrypted} <- Base.decode64(decoded_data),
         {:ok, decrypted} <- AesGcm.decrypt_with_key(cipher_key, encrypted),
         {:ok, decompressed} <- maybe_decompress(decrypted, encrypt_type),
         {:ok, decoded} <- Jason.decode(decompressed) do
      Map.put(original_payload, "data", decoded)
    else
      :error ->
        Logger.warning("Failed to decrypt event data: invalid_base64_data")
        original_payload

      {:error, reason} ->
        Logger.warning("Failed to decrypt event data: #{inspect(reason)}")
        original_payload
    end
  end

  @max_event_json_bytes 5_000_000

  defp maybe_decompress(data, encrypt_type) when encrypt_type in [1, 2] do
    try do
      decompressed = :zlib.gunzip(data)

      if byte_size(decompressed) > @max_event_json_bytes do
        {:error, :decompressed_too_large}
      else
        {:ok, decompressed}
      end
    catch
      :error, _reason ->
        try_inflate_fallback(data)
    end
  end

  defp maybe_decompress(data, _encrypt_type), do: {:ok, data}

  defp try_inflate_fallback(data) do
    z = :zlib.open()

    try do
      :ok = :zlib.inflateInit(z, 31)
      decompressed = :zlib.inflate(z, data) |> IO.iodata_to_binary()
      :zlib.inflateEnd(z)

      if byte_size(decompressed) > @max_event_json_bytes do
        {:error, :decompressed_too_large}
      else
        {:ok, decompressed}
      end
    catch
      :error, reason -> {:error, {:decompress_failed, reason}}
    after
      :zlib.close(z)
    end
  end

  defp do_send_frame(state, frame) do
    case Mint.WebSocket.encode(state.websocket, {:binary, frame}) do
      {:ok, websocket, data} ->
        case Mint.WebSocket.stream_request_body(state.conn, state.ref, data) do
          {:ok, conn} ->
            {:ok, %{state | conn: conn, websocket: websocket}}

          {:error, conn, reason} ->
            {:error, reason, %{state | conn: conn, websocket: websocket}}
        end

      {:error, websocket, reason} ->
        {:error, reason, %{state | websocket: websocket}}
    end
  end

  defp schedule_ping(state) do
    if state.ping_timer, do: Process.cancel_timer(state.ping_timer)
    timer = Process.send_after(self(), :ping, @ping_interval_ms)
    %{state | ping_timer: timer}
  end
end
