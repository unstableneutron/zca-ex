defmodule ZcaEx.Crypto.AesGcm do
  @moduledoc """
  AES-GCM decryption for WebSocket event data.

  Data format from encrypted buffer:
  - bytes[0..15]: IV (16 bytes)
  - bytes[16..31]: AAD/additionalData (16 bytes)
  - bytes[32..end]: ciphertext + auth tag (tag is last 16 bytes)
  """

  @iv_size 16
  @aad_size 16
  @tag_size 16
  @min_encrypted_size @iv_size + @aad_size + @tag_size

  @doc """
  Decrypt AES-GCM encrypted data from WebSocket events.

  ## Parameters
  - `cipher_key_base64` - Base64-encoded cipher key from WS handshake
  - `encrypted_data` - Raw bytes (already Base64 decoded by caller)

  ## Returns
  - `{:ok, plaintext}` on success
  - `{:error, reason}` on failure
  """
  @spec decrypt(cipher_key :: String.t(), encrypted_data :: binary()) ::
          {:ok, binary()} | {:error, term()}
  def decrypt(cipher_key_base64, encrypted_data)
      when is_binary(cipher_key_base64) and is_binary(encrypted_data) do
    with {:ok, key} <- decode_key(cipher_key_base64),
         :ok <- validate_data_length(encrypted_data),
         {:ok, plaintext} <- do_decrypt(key, encrypted_data) do
      {:ok, plaintext}
    end
  end

  def decrypt(_cipher_key, _encrypted_data), do: {:error, :invalid_arguments}

  defp decode_key(base64_key) do
    case Base.decode64(base64_key) do
      {:ok, key} when byte_size(key) in [16, 24, 32] -> {:ok, key}
      {:ok, _key} -> {:error, :invalid_key_size}
      :error -> {:error, :invalid_base64_key}
    end
  end

  defp validate_data_length(data) when byte_size(data) >= @min_encrypted_size, do: :ok
  defp validate_data_length(_data), do: {:error, :data_too_short}

  defp do_decrypt(key, encrypted_data) do
    <<iv::binary-size(@iv_size), aad::binary-size(@aad_size), data_with_tag::binary>> =
      encrypted_data

    data_len = byte_size(data_with_tag) - @tag_size
    <<ciphertext::binary-size(data_len), tag::binary-size(@tag_size)>> = data_with_tag

    cipher = cipher_for_key(key)

    case :crypto.crypto_one_time_aead(cipher, key, iv, ciphertext, aad, tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> {:error, :decryption_failed}
    end
  end

  defp cipher_for_key(key) do
    case byte_size(key) do
      16 -> :aes_128_gcm
      24 -> :aes_192_gcm
      32 -> :aes_256_gcm
    end
  end
end
