defmodule ZcaEx.Account.Credentials do
  @moduledoc "Zalo account credentials"

  @type cookie_source :: String.t() | [map()] | map()

  @type t :: %__MODULE__{
          imei: String.t(),
          user_agent: String.t(),
          cookies: cookie_source(),
          language: String.t(),
          secret_key: String.t() | nil,
          api_type: integer(),
          api_version: integer()
        }

  @enforce_keys [:imei, :user_agent, :cookies]
  defstruct [
    :imei,
    :user_agent,
    :cookies,
    :secret_key,
    language: "vi",
    api_type: 30,
    api_version: 665
  ]

  @spec new(keyword()) :: {:ok, t()} | {:error, {:missing_required, atom()}}
  def new(opts) do
    with {:ok, imei} <- fetch_required(opts, :imei),
         {:ok, user_agent} <- fetch_required(opts, :user_agent),
         {:ok, cookies} <- fetch_cookies(opts) do
      normalized_cookies = normalize_cookies(cookies)

      {:ok,
       %__MODULE__{
         imei: imei,
         user_agent: user_agent,
         cookies: normalized_cookies,
         language: Keyword.get(opts, :language, "vi"),
         secret_key: Keyword.get(opts, :secret_key),
         api_type: Keyword.get(opts, :api_type, 30),
         api_version: Keyword.get(opts, :api_version, 665)
       }}
    end
  end

  @spec new!(keyword()) :: t()
  def new!(opts) do
    case new(opts) do
      {:ok, credentials} -> credentials
      {:error, reason} -> raise ArgumentError, "Invalid credentials: #{inspect(reason)}"
    end
  end

  defp fetch_required(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when not is_nil(value) -> {:ok, value}
      _ -> {:error, {:missing_required, key}}
    end
  end

  defp fetch_cookies(opts) do
    case Keyword.fetch(opts, :cookies) do
      {:ok, value} when not is_nil(value) -> {:ok, value}
      _ ->
        case Keyword.fetch(opts, :cookie) do
          {:ok, value} when not is_nil(value) -> {:ok, value}
          _ -> {:error, {:missing_required, :cookies}}
        end
    end
  end

  defp normalize_cookies(%{"cookies" => cookies}) when is_list(cookies), do: cookies
  defp normalize_cookies(cookies), do: cookies

  @spec to_map(t(), keyword()) :: map()
  def to_map(%__MODULE__{} = credentials, opts \\ []) do
    include_sensitive? = Keyword.get(opts, :include_sensitive?, false)
    normalized_cookies = normalize_cookies_to_list(credentials.cookies)

    base = %{
      "imei" => credentials.imei,
      "user_agent" => credentials.user_agent,
      "language" => credentials.language,
      "api_type" => credentials.api_type,
      "api_version" => credentials.api_version
    }

    if include_sensitive? do
      base
      |> Map.put("cookies", normalized_cookies)
      |> Map.put("secret_key", credentials.secret_key)
    else
      base
    end
  end

  defp normalize_cookies_to_list(cookies) when is_list(cookies), do: cookies
  defp normalize_cookies_to_list(%{"cookies" => cookies}) when is_list(cookies), do: cookies
  defp normalize_cookies_to_list(cookie_string) when is_binary(cookie_string) do
    cookie_string
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn cookie_part ->
      case String.split(cookie_part, "=", parts: 2) do
        [name, value] -> %{"name" => String.trim(name), "value" => String.trim(value)}
        [name] -> %{"name" => String.trim(name), "value" => ""}
      end
    end)
  end
  defp normalize_cookies_to_list(cookies) when is_map(cookies), do: [cookies]

  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(map) when is_map(map) do
    with {:ok, imei} <- require_field(map, :imei),
         {:ok, user_agent} <- require_field(map, :user_agent),
         {:ok, cookies} <- require_field(map, :cookies) do
      {:ok,
       %__MODULE__{
         imei: imei,
         user_agent: user_agent,
         cookies: normalize_cookies(cookies),
         language: get_field(map, :language) || "vi",
         secret_key: get_field(map, :secret_key),
         api_type: get_field(map, :api_type) || 30,
         api_version: get_field(map, :api_version) || 665
       }}
    end
  end

  @spec from_map!(map()) :: t()
  def from_map!(map) do
    case from_map(map) do
      {:ok, credentials} -> credentials
      {:error, reason} -> raise ArgumentError, "Invalid credentials map: #{inspect(reason)}"
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
