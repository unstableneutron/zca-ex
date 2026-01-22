defmodule ZcaEx.Crypto.ParamsEncryptor do
  @moduledoc "ParamsEncryptor for ZCID generation"

  alias ZcaEx.Crypto.{AesCbc, MD5}

  @zcid_key "3FC4F0D2AB50057BCE0D90D9187A22B1"

  defstruct [:zcid, :zcid_ext, :encrypt_key, enc_ver: "v2"]

  @type t :: %__MODULE__{
          zcid: String.t(),
          zcid_ext: String.t(),
          encrypt_key: String.t(),
          enc_ver: String.t()
        }

  @doc "Create a new ParamsEncryptor with random zcid_ext"
  @spec new(integer(), String.t(), integer()) :: t()
  def new(type, imei, first_launch_time) do
    zcid_ext = random_string()
    new(type, imei, first_launch_time, zcid_ext)
  end

  @doc "Create a new ParamsEncryptor with specific zcid_ext (for testing)"
  @spec new(integer(), String.t(), integer(), String.t()) :: t()
  def new(type, imei, first_launch_time, zcid_ext) do
    zcid = create_zcid(type, imei, first_launch_time)
    encrypt_key = create_encrypt_key(zcid, zcid_ext)

    %__MODULE__{
      zcid: zcid,
      zcid_ext: zcid_ext,
      encrypt_key: encrypt_key
    }
  end

  @doc "Get params for API requests"
  @spec get_params(t()) :: %{zcid: String.t(), zcid_ext: String.t(), enc_ver: String.t()}
  def get_params(%__MODULE__{zcid: zcid, zcid_ext: zcid_ext, enc_ver: enc_ver}) do
    %{zcid: zcid, zcid_ext: zcid_ext, enc_ver: enc_ver}
  end

  @doc "Get the encrypt key"
  @spec get_encrypt_key(t()) :: String.t()
  def get_encrypt_key(%__MODULE__{encrypt_key: encrypt_key}), do: encrypt_key

  @doc "Encrypt with UTF-8 key (static method)"
  @spec encode_aes(String.t(), String.t(), :hex | :base64, boolean()) :: String.t() | nil
  def encode_aes(key, message, output_format, uppercase?) do
    AesCbc.encrypt_utf8_key(key, message, output_format, uppercase?)
  end

  # Private functions

  defp create_zcid(type, imei, first_launch_time) do
    msg = "#{type},#{imei},#{first_launch_time}"
    AesCbc.encrypt_utf8_key(@zcid_key, msg, :hex, true)
  end

  defp create_encrypt_key(zcid, zcid_ext) do
    zcid_ext_md5 = zcid_ext |> MD5.hash_hex() |> String.upcase()
    {even_md5, _odd_md5} = process_str(zcid_ext_md5)
    {even_zcid, odd_zcid} = process_str(zcid)

    (Enum.take(even_md5, 8) ++
       Enum.take(even_zcid, 12) ++
       (odd_zcid |> Enum.reverse() |> Enum.take(12)))
    |> Enum.join("")
  end

  defp process_str(str) when is_binary(str) do
    str
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.split_with(fn {_char, index} -> rem(index, 2) == 0 end)
    |> then(fn {evens, odds} ->
      {Enum.map(evens, fn {char, _} -> char end), Enum.map(odds, fn {char, _} -> char end)}
    end)
  end

  defp random_string do
    len = Enum.random(6..12)

    :crypto.strong_rand_bytes(len)
    |> Base.encode16(case: :lower)
    |> String.slice(0, len)
  end
end
