defmodule ZcaEx.CookieJar.Jar do
  @moduledoc "GenServer for cookie storage using ETS with RFC6265 compliance"

  use GenServer

  alias ZcaEx.CookieJar.{Cookie, Parser, Policy}

  @type account_id :: term()

  def start_link(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    name = via_tuple(account_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec store(account_id(), URI.t() | String.t(), String.t()) :: :ok | {:error, term()}
  def store(account_id, uri, set_cookie_header) do
    uri = ensure_uri(uri)
    GenServer.call(via_tuple(account_id), {:store, uri, set_cookie_header})
  end

  @spec get_cookie_string(account_id(), URI.t() | String.t()) :: String.t()
  def get_cookie_string(account_id, uri) do
    uri = ensure_uri(uri)
    GenServer.call(via_tuple(account_id), {:get_cookie_string, uri})
  end

  @spec export(account_id()) :: [map()]
  def export(account_id) do
    GenServer.call(via_tuple(account_id), :export)
  end

  @spec import(account_id(), [map()] | map()) :: :ok
  def import(account_id, cookies) do
    GenServer.call(via_tuple(account_id), {:import, cookies})
  end

  defp via_tuple(account_id) do
    {:via, Registry, {ZcaEx.Registry, {:cookie_jar, account_id}}}
  end

  defp ensure_uri(%URI{} = uri), do: uri
  defp ensure_uri(uri) when is_binary(uri), do: URI.parse(uri)

  @impl true
  def init(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    table = :ets.new(:cookie_jar, [:set, :private])

    state = %{
      account_id: account_id,
      table: table
    }

    case Keyword.get(opts, :cookies) do
      nil -> :ok
      cookies -> do_import(table, cookies)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:store, uri, header}, _from, state) do
    result =
      case Parser.parse(header, uri) do
        {:ok, cookie} ->
          key = {cookie.domain, cookie.path, cookie.name}

          if cookie.expires_at == 0 do
            :ets.delete(state.table, key)
          else
            :ets.insert(state.table, {key, cookie})
          end

          :ok

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, state}
  end

  def handle_call({:get_cookie_string, uri}, _from, state) do
    cookies = get_matching_cookies(state.table, uri)

    cookie_string =
      cookies
      |> Enum.sort_by(fn c -> {-String.length(c.path), c.creation_time} end)
      |> Enum.map(fn c -> "#{c.name}=#{c.value}" end)
      |> Enum.join("; ")

    {:reply, cookie_string, state}
  end

  def handle_call(:export, _from, state) do
    now = System.system_time(:second)

    cookies =
      :ets.tab2list(state.table)
      |> Enum.map(fn {_key, cookie} -> cookie end)
      |> Enum.reject(&expired?(&1, now))
      |> Enum.map(&cookie_to_map/1)

    {:reply, cookies, state}
  end

  def handle_call({:import, cookies}, _from, state) do
    do_import(state.table, cookies)
    {:reply, :ok, state}
  end

  defp do_import(table, %{"cookies" => cookies}), do: do_import(table, cookies)
  defp do_import(table, %{cookies: cookies}), do: do_import(table, cookies)

  defp do_import(table, cookies) when is_list(cookies) do
    Enum.each(cookies, fn cookie_map ->
      cookie = map_to_cookie(cookie_map)
      key = {cookie.domain, cookie.path, cookie.name}
      :ets.insert(table, {key, cookie})
    end)
  end

  defp get_matching_cookies(table, uri) do
    now = System.system_time(:second)
    host = Policy.normalize_domain(uri.host || "")
    path = uri.path || "/"
    secure = uri.scheme == "https"

    :ets.tab2list(table)
    |> Enum.map(fn {_key, cookie} -> cookie end)
    |> Enum.filter(fn cookie ->
      not expired?(cookie, now) and
        Policy.domain_matches?(host, cookie) and
        Policy.path_matches?(path, cookie.path) and
        (not cookie.secure or secure)
    end)
  end

  defp expired?(%Cookie{expires_at: nil}, _now), do: false
  defp expired?(%Cookie{expires_at: 0}, _now), do: true
  defp expired?(%Cookie{expires_at: expires_at}, now), do: expires_at <= now

  defp cookie_to_map(%Cookie{} = cookie) do
    %{
      "name" => cookie.name,
      "value" => cookie.value,
      "domain" => cookie.domain,
      "path" => cookie.path,
      "secure" => cookie.secure,
      "httpOnly" => cookie.http_only,
      "hostOnly" => cookie.host_only,
      "expiresAt" => cookie.expires_at,
      "creationTime" => cookie.creation_time,
      "sameSite" => cookie.same_site,
      "maxAge" => cookie.max_age
    }
  end

  defp map_to_cookie(map) do
    %Cookie{
      name: get_string(map, ["name"]),
      value: get_string(map, ["value"]),
      domain: get_string(map, ["domain"]),
      path: get_string(map, ["path"]) || "/",
      secure: get_bool(map, ["secure"]),
      http_only: get_bool(map, ["httpOnly", "http_only"]),
      host_only: get_bool(map, ["hostOnly", "host_only"]),
      expires_at: get_int(map, ["expiresAt", "expires_at"]),
      creation_time:
        get_int(map, ["creationTime", "creation_time"]) || System.system_time(:second),
      same_site: get_same_site(map, ["sameSite", "same_site"]),
      max_age: get_int(map, ["maxAge", "max_age"])
    }
  end

  defp get_string(map, keys) do
    Enum.find_value(keys, fn key ->
      Map.get(map, key) || Map.get(map, String.to_atom(key))
    end)
  end

  defp get_bool(map, keys) do
    Enum.find_value(keys, false, fn key ->
      case Map.get(map, key) || Map.get(map, String.to_atom(key)) do
        nil -> nil
        val -> val
      end
    end)
  end

  defp get_int(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.get(map, key) || Map.get(map, String.to_atom(key)) do
        nil -> nil
        val when is_integer(val) -> val
        val when is_binary(val) -> String.to_integer(val)
        _ -> nil
      end
    end)
  end

  defp get_same_site(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.get(map, key) || Map.get(map, String.to_atom(key)) do
        nil -> nil
        val when is_atom(val) -> val
        "strict" -> :strict
        "lax" -> :lax
        "none" -> :none
        _ -> nil
      end
    end)
  end
end
