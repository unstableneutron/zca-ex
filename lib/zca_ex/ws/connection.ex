defmodule ZcaEx.WS.Connection do
  @moduledoc """
  WebSocket connection GenServer for Zalo real-time events.

  Manages the WebSocket connection lifecycle using mint_web_socket.
  States: :disconnected -> :connecting -> :connected -> :ready
  """
  use GenServer
  require Logger

  alias ZcaEx.Account.Session
  alias ZcaEx.CookieJar
  alias ZcaEx.Crypto.AesGcm
  alias ZcaEx.Events.Dispatcher
  alias ZcaEx.WS.{ControlParser, Frame, Router}

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
    endpoint_index: 0,
    retry_counters: %{},
    state: :disconnected,
    request_id: 0
  ]

  @type t :: %__MODULE__{
          account_id: String.t(),
          session: Session.t() | nil,
          conn: Mint.HTTP.t() | nil,
          websocket: Mint.WebSocket.t() | nil,
          ref: reference() | nil,
          cipher_key: String.t() | nil,
          ping_timer: reference() | nil,
          user_agent: String.t() | nil,
          upgrade_status: non_neg_integer() | nil,
          endpoint_index: non_neg_integer(),
          retry_counters: map(),
          state: :disconnected | :connecting | :connected | :ready,
          request_id: non_neg_integer()
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
    state = %{state | session: session, user_agent: user_agent, state: :connecting}

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
    new_state = do_disconnect(state)
    {:reply, :ok, new_state}
  end

  def handle_call({:send_frame, frame}, _from, %{state: :ready} = state) do
    case do_send_frame(state, frame) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call({:send_frame, _frame}, _from, state) do
    {:reply, {:error, :not_ready}, state}
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

  def handle_info(message, %{conn: conn} = state) when conn != nil do
    case Mint.WebSocket.stream(conn, message) do
      {:ok, conn, responses} ->
        state = %{state | conn: conn}
        {:noreply, handle_responses(responses, state)}

      {:error, conn, reason, _responses} ->
        Logger.warning("WebSocket stream error: #{inspect(reason)}")
        new_state = %{state | conn: conn}
        {:noreply, do_disconnect(new_state)}

      :unknown ->
        {:noreply, state}
    end
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    do_disconnect(state)
    :ok
  end

  ## Private Functions

  defp via(account_id), do: {:via, Registry, {ZcaEx.Registry, {:ws, account_id}}}

  defp do_connect(state) do
    %{session: session, endpoint_index: idx, account_id: account_id, user_agent: user_agent} =
      state

    endpoint = Enum.at(session.ws_endpoints, idx) || hd(session.ws_endpoints)
    uri = build_ws_uri(endpoint, session)

    cookies = CookieJar.get_cookie_string(account_id, "https://chat.zalo.me")

    headers = [
      {"accept-encoding", "gzip, deflate, br, zstd"},
      {"accept-language", "en-US,en;q=0.9"},
      {"cache-control", "no-cache"},
      {"origin", "https://chat.zalo.me"},
      {"user-agent", user_agent},
      {"cookie", cookies}
    ]

    scheme = if uri.scheme == "wss", do: :https, else: :http
    port = uri.port || if(scheme == :https, do: 443, else: 80)

    with {:ok, conn} <- Mint.HTTP.connect(scheme, uri.host, port, protocols: [:http1]),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(scheme, conn, ws_path(uri), headers) do
      {:ok, %{state | conn: conn, ref: ref, state: :connecting}}
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

  defp do_disconnect(state) do
    if state.ping_timer, do: Process.cancel_timer(state.ping_timer)

    if state.conn do
      _ = Mint.HTTP.close(state.conn)
    end

    Dispatcher.dispatch_lifecycle(state.account_id, :disconnected, %{})

    %{
      state
      | conn: nil,
        websocket: nil,
        ref: nil,
        cipher_key: nil,
        ping_timer: nil,
        state: :disconnected
    }
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
        %{state | conn: conn}
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
    do_disconnect(state)
  end

  defp handle_response({:error, ref, reason}, %{ref: ref} = state) do
    Logger.error("WebSocket error: #{inspect(reason)}")
    Dispatcher.dispatch_lifecycle(state.account_id, :error, %{reason: reason})
    do_disconnect(state)
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
    do_disconnect(state)
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
        do_disconnect(state)

      :unknown ->
        Logger.debug("Unknown event: #{inspect(header)}")
        state

      _ ->
        dispatch_event(event_type, thread_type, payload, state)
    end
  end

  defp handle_cipher_key(%{"key" => key}, state) do
    Logger.debug("Received cipher key")
    Dispatcher.dispatch(state.account_id, :cipher_key, %{key: key})

    state
    |> Map.put(:cipher_key, key)
    |> Map.put(:state, :ready)
    |> schedule_ping()
  end

  defp handle_cipher_key(_payload, state), do: state

  defp dispatch_event(:control, _thread_type, payload, state) do
    # Control events are not encrypted, parse and dispatch each sub-event
    payload
    |> ControlParser.parse()
    |> Enum.each(fn {event_type, event_payload} ->
      Dispatcher.dispatch(state.account_id, event_type, event_payload)
    end)

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
         {:ok, decrypted} <- AesGcm.decrypt(cipher_key, encrypted),
         {:ok, decompressed} <- maybe_decompress(decrypted, encrypt_type),
         {:ok, decoded} <- Jason.decode(decompressed) do
      Map.put(original_payload, "data", decoded)
    else
      {:error, reason} ->
        Logger.warning("Failed to decrypt event data: #{inspect(reason)}")
        original_payload
    end
  end

  defp maybe_decompress(data, encrypt_type) when encrypt_type in [1, 2] do
    try do
      decompressed = :zlib.unzip(data)
      {:ok, decompressed}
    rescue
      _ ->
        try do
          z = :zlib.open()
          :ok = :zlib.inflateInit(z, -15)
          decompressed = :zlib.inflate(z, data) |> IO.iodata_to_binary()
          :zlib.inflateEnd(z)
          :zlib.close(z)
          {:ok, decompressed}
        rescue
          e -> {:error, {:decompress_failed, e}}
        end
    end
  end

  defp maybe_decompress(data, _encrypt_type), do: {:ok, data}

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
