defmodule ZcaEx.Account.Manager do
  @moduledoc "Manages state and operations for a single Zalo account"
  use GenServer
  require Logger

  alias ZcaEx.Account.Session
  alias ZcaEx.Api.Endpoints.GetLoginInfo
  alias ZcaEx.{CookieJar, HTTP}
  alias ZcaEx.Crypto.SignKey
  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  defstruct [:account_id, :credentials, :session, state: :initialized]

  def start_link(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    GenServer.start_link(__MODULE__, opts, name: via(account_id))
  end

  defp via(account_id), do: {:via, Registry, {ZcaEx.Registry, {:account, account_id}}}

  def login(account_id), do: GenServer.call(via(account_id), :login, 30_000)
  def get_session(account_id), do: GenServer.call(via(account_id), :get_session)
  def get_state(account_id), do: GenServer.call(via(account_id), :get_state)

  @doc "Inject or replace the session for an account"
  def put_session(account_id, %Session{} = session) do
    GenServer.call(via(account_id), {:put_session, session})
  end

  @impl true
  def init(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    credentials = Keyword.fetch!(opts, :credentials)
    session = Keyword.get(opts, :session)

    base = %__MODULE__{
      account_id: account_id,
      credentials: credentials,
      state: :initialized
    }

    state =
      if session do
        %{base | session: session, state: :logged_in}
      else
        base
      end

    {:ok, state}
  end

  @impl true
  def handle_call(:login, _from, %{state: :logged_in} = state) do
    {:reply, {:ok, state.session}, state}
  end

  def handle_call(:login, _from, state) do
    case do_login(state) do
      {:ok, session} ->
        {:reply, {:ok, session}, %{state | session: session, state: :logged_in}}

      {:error, reason} ->
        {:reply, {:error, reason}, %{state | state: :login_failed}}
    end
  end

  def handle_call(:get_session, _from, state) do
    {:reply, state.session, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end

  def handle_call({:put_session, session}, _from, state) do
    {:reply, :ok, %{state | session: session, state: :logged_in}}
  end

  defp do_login(state) do
    %{account_id: account_id, credentials: creds} = state

    with :ok <- import_cookies(account_id, creds.cookies),
         {:ok, login_info} <- fetch_login_info(account_id, creds),
         {:ok, server_info} <- fetch_server_info(account_id, creds) do
      session = %Session{
        uid: to_string(login_info["uid"]),
        secret_key: login_info["zpw_enk"],
        zpw_service_map: login_info["zpw_service_map_v3"] || %{},
        ws_endpoints: get_ws_endpoints(server_info),
        api_type: creds.api_type,
        api_version: creds.api_version
      }

      {:ok, session}
    end
  end

  defp import_cookies(account_id, cookies) when is_list(cookies) do
    CookieJar.import(account_id, cookies)
    :ok
  end

  defp import_cookies(account_id, cookie_string) when is_binary(cookie_string) do
    cookies =
      cookie_string
      |> String.split(";")
      |> Enum.map(&String.trim/1)
      |> Enum.map(fn pair ->
        case String.split(pair, "=", parts: 2) do
          [name, value] ->
            %{"name" => name, "value" => value, "domain" => ".zalo.me", "path" => "/"}

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    CookieJar.import(account_id, cookies)
    :ok
  end

  defp fetch_login_info(account_id, creds) do
    GetLoginInfo.call(
      account_id,
      creds.imei,
      creds.user_agent,
      api_type: creds.api_type,
      api_version: creds.api_version,
      language: creds.language
    )
  end

  defp fetch_server_info(account_id, creds) do
    sign_params = %{
      imei: creds.imei,
      type: creds.api_type,
      client_version: creds.api_version,
      computer_name: "Web"
    }

    params = Map.put(sign_params, :signkey, SignKey.generate("getserverinfo", sign_params))

    url =
      HTTP.build_url("https://wpa.chat.zalo.me/api/login/getServerInfo", params,
        api_version: false
      )

    case AccountClient.get(account_id, url, creds.user_agent) do
      {:ok, %{status: 200, body: body}} ->
        resp = Jason.decode!(body)

        if resp["data"] do
          {:ok, resp["data"]}
        else
          {:error,
           Error.api(resp["error_code"], resp["error_message"] || "Failed to get server info")}
        end

      result ->
        {:error, normalize_server_info_error(result)}
    end
  end

  @doc false
  def normalize_server_info_error(result) do
    case result do
      {:ok, %{status: status}} when is_integer(status) ->
        Error.api(status, "HTTP #{status}")

      {:error, reason} ->
        Error.normalize({:error, reason})

      other ->
        Error.normalize(other)
    end
  end

  defp get_ws_endpoints(server_info) do
    case server_info["zpw_ws"] do
      # List of maps with "endpoint" key
      [%{"endpoint" => _} | _] = ws -> Enum.map(ws, fn e -> e["endpoint"] end)
      # List of strings (direct URLs)
      [url | _] = ws when is_binary(url) -> ws
      # Single string
      url when is_binary(url) -> [url]
      _ -> ["wss://ws1.chat.zalo.me/ws/v2/webchat/socket"]
    end
  end
end
