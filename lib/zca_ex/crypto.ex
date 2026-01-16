defmodule ZcaEx.Crypto do
  @moduledoc "Crypto utilities for Zalo API"

  alias ZcaEx.Crypto.{AesCbc, MD5, ParamsEncryptor, SignKey}

  defdelegate md5(data), to: MD5, as: :hash_hex
  defdelegate sign_key(type, params), to: SignKey, as: :generate
  defdelegate encrypt_aes_cbc(key, plaintext, format, uppercase?), to: AesCbc, as: :encrypt_utf8_key
  defdelegate decrypt_aes_cbc(key, ciphertext), to: AesCbc, as: :decrypt_base64_key
  defdelegate new_params_encryptor(type, imei, first_launch_time), to: ParamsEncryptor, as: :new
  defdelegate get_encrypt_key(encryptor), to: ParamsEncryptor
  defdelegate get_params(encryptor), to: ParamsEncryptor
end
