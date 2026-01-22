defmodule ZcaEx.Crypto.AesCbc do
  @moduledoc "AES-CBC encryption/decryption with PKCS7 padding"

  @zero_iv <<0::128>>
  @block_size 16

  @doc """
  Encrypt with a UTF-8 string key (32 chars).
  Returns hex or base64 encoded ciphertext.
  """
  @spec encrypt_utf8_key(String.t(), String.t(), :hex | :base64, boolean()) :: String.t() | nil
  def encrypt_utf8_key(key, plaintext, output_format, uppercase? \\ false)

  def encrypt_utf8_key(_key, "", _output_format, _uppercase?), do: nil
  def encrypt_utf8_key(_key, nil, _output_format, _uppercase?), do: nil

  def encrypt_utf8_key(key, plaintext, output_format, uppercase?)
      when is_binary(key) and is_binary(plaintext) do
    padded = pkcs7_pad(plaintext)
    cipher = cipher_for_key(key)
    ciphertext = :crypto.crypto_one_time(cipher, key, @zero_iv, padded, true)

    encoded =
      case output_format do
        :hex -> Base.encode16(ciphertext, case: :lower)
        :base64 -> Base.encode64(ciphertext)
      end

    if uppercase?, do: String.upcase(encoded), else: encoded
  end

  @doc """
  Encrypt with a Base64-encoded key.
  Returns base64-encoded ciphertext.
  """
  @spec encrypt_base64_key(binary(), String.t()) :: String.t() | nil
  def encrypt_base64_key(_key, ""), do: nil
  def encrypt_base64_key(_key, nil), do: nil

  def encrypt_base64_key(key, plaintext) when is_binary(key) and is_binary(plaintext) do
    padded = pkcs7_pad(plaintext)
    cipher = cipher_for_key(key)
    ciphertext = :crypto.crypto_one_time(cipher, key, @zero_iv, padded, true)
    Base.encode64(ciphertext)
  end

  @doc """
  Decrypt with a Base64-encoded key.
  Returns plaintext string.
  """
  @spec decrypt_base64_key(String.t(), String.t()) :: String.t() | {:error, term()}
  def decrypt_base64_key(base64_key, ciphertext_base64) do
    with {:ok, key} <- Base.decode64(base64_key),
         {:ok, ciphertext} <- Base.decode64(ciphertext_base64) do
      cipher = cipher_for_key(key)
      padded_plaintext = :crypto.crypto_one_time(cipher, key, @zero_iv, ciphertext, false)
      pkcs7_unpad(padded_plaintext)
    end
  end

  @doc """
  Decrypt with a UTF-8 string key (32 chars).
  Returns plaintext string.
  """
  @spec decrypt_utf8_key(String.t(), String.t(), :hex | :base64) :: String.t() | nil
  def decrypt_utf8_key(_key, nil, _input_format), do: nil
  def decrypt_utf8_key(_key, "", _input_format), do: nil

  def decrypt_utf8_key(key, ciphertext, input_format)
      when is_binary(key) and is_binary(ciphertext) do
    # URL-decode first to match JS decodeRespAES behavior
    url_decoded = URI.decode(ciphertext)

    decoded =
      case input_format do
        :hex -> Base.decode16!(url_decoded, case: :mixed)
        :base64 -> Base.decode64!(url_decoded)
      end

    cipher = cipher_for_key(key)
    padded_plaintext = :crypto.crypto_one_time(cipher, key, @zero_iv, decoded, false)
    pkcs7_unpad(padded_plaintext)
  end

  defp cipher_for_key(key) do
    case byte_size(key) do
      16 -> :aes_128_cbc
      24 -> :aes_192_cbc
      32 -> :aes_256_cbc
    end
  end

  @doc "Apply PKCS7 padding to data"
  @spec pkcs7_pad(binary()) :: binary()
  def pkcs7_pad(data) do
    padding_length = @block_size - rem(byte_size(data), @block_size)
    data <> :binary.copy(<<padding_length>>, padding_length)
  end

  @doc "Remove PKCS7 padding from data"
  @spec pkcs7_unpad(binary()) :: String.t()
  def pkcs7_unpad(data) when byte_size(data) == 0, do: <<>>

  def pkcs7_unpad(data) do
    pad_len = :binary.last(data)

    if pad_len > 0 and pad_len <= 16 do
      data_len = byte_size(data) - pad_len
      padding = :binary.part(data, data_len, pad_len)
      expected_padding = :binary.copy(<<pad_len>>, pad_len)

      if padding == expected_padding do
        :binary.part(data, 0, data_len)
      else
        # Invalid padding, return as-is (might be unpadded already)
        data
      end
    else
      data
    end
  end
end
