defmodule ZcaEx.Crypto.SignKey do
  @moduledoc "Generate signed keys for API requests"

  alias ZcaEx.Crypto.MD5

  @spec generate(String.t(), map()) :: String.t()
  def generate(type, params) when is_binary(type) and is_map(params) do
    sorted_keys =
      params
      |> Map.keys()
      |> Enum.map(&to_string/1)
      |> Enum.sort()

    values =
      Enum.map(sorted_keys, fn k ->
        to_string(params[k] || params[String.to_existing_atom(k)])
      end)

    MD5.hash_hex("zsecure" <> type <> Enum.join(values, ""))
  end
end
