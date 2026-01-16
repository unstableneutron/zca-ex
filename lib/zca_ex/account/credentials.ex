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
end
