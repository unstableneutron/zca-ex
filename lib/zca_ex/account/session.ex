defmodule ZcaEx.Account.Session do
  @moduledoc "Session state for an authenticated Zalo account"

  @type t :: %__MODULE__{
          uid: String.t(),
          secret_key: String.t(),
          zpw_service_map: map(),
          ws_endpoints: [String.t()],
          api_type: integer(),
          api_version: integer(),
          settings: map() | nil,
          login_info: map() | nil,
          extra_ver: map() | nil
        }

  defstruct [
    :uid,
    :secret_key,
    :zpw_service_map,
    :settings,
    :login_info,
    :extra_ver,
    ws_endpoints: [],
    api_type: 30,
    api_version: 645
  ]

  @spec from_login_response(map()) :: t()
  def from_login_response(data) when is_map(data) do
    %__MODULE__{
      uid: to_string(get_in(data, ["uid"]) || get_in(data, [:uid])),
      secret_key: get_in(data, ["zpw_enk"]) || get_in(data, [:zpw_enk]),
      zpw_service_map: get_in(data, ["zpw_service_map_v3"]) || get_in(data, [:zpw_service_map_v3]) || %{},
      settings: get_in(data, ["settings"]) || get_in(data, [:settings]),
      login_info: extract_login_info(data),
      extra_ver: get_in(data, ["extra_ver"]) || get_in(data, [:extra_ver])
    }
  end

  defp extract_login_info(data) do
    %{
      "isNewAccount" => get_in(data, ["isNewAccount"]) || get_in(data, [:isNewAccount]),
      "avatar" => get_in(data, ["avatar"]) || get_in(data, [:avatar]),
      "displayName" => get_in(data, ["displayName"]) || get_in(data, [:displayName]),
      "phoneNumber" => get_in(data, ["phoneNumber"]) || get_in(data, [:phoneNumber])
    }
  end

  @spec to_map(t(), keyword()) :: map()
  def to_map(%__MODULE__{} = session, opts \\ []) do
    include_sensitive? = Keyword.get(opts, :include_sensitive?, false)

    base = %{
      "uid" => session.uid,
      "zpw_service_map" => session.zpw_service_map,
      "ws_endpoints" => session.ws_endpoints,
      "api_type" => session.api_type,
      "api_version" => session.api_version,
      "settings" => session.settings,
      "login_info" => session.login_info,
      "extra_ver" => session.extra_ver
    }

    if include_sensitive? do
      Map.put(base, "secret_key", session.secret_key)
    else
      base
    end
  end

  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(map) when is_map(map) do
    with {:ok, uid} <- require_field(map, :uid),
         {:ok, secret_key} <- require_field(map, :secret_key),
         {:ok, zpw_service_map} <- require_field(map, :zpw_service_map) do
      {:ok,
       %__MODULE__{
         uid: to_string(uid),
         secret_key: secret_key,
         zpw_service_map: zpw_service_map,
         ws_endpoints: get_field(map, :ws_endpoints) || [],
         api_type: get_field(map, :api_type) || 30,
         api_version: get_field(map, :api_version) || 645,
         settings: get_field(map, :settings),
         login_info: get_field(map, :login_info),
         extra_ver: get_field(map, :extra_ver)
       }}
    end
  end

  @spec from_map!(map()) :: t()
  def from_map!(map) do
    case from_map(map) do
      {:ok, session} -> session
      {:error, reason} -> raise ArgumentError, "Invalid session map: #{inspect(reason)}"
    end
  end

  defp get_field(map, key) when is_atom(key) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp require_field(map, key) do
    case get_field(map, key) do
      nil -> {:error, {:missing_required, key}}
      value -> {:ok, value}
    end
  end
end
