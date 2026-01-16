defmodule ZcaEx.Crypto.MD5 do
  @moduledoc "MD5 hash utilities"

  @spec hash(binary()) :: binary()
  def hash(data) when is_binary(data) do
    :crypto.hash(:md5, data)
  end

  @spec hash_hex(binary()) :: String.t()
  def hash_hex(data) when is_binary(data) do
    data |> hash() |> Base.encode16(case: :lower)
  end
end
