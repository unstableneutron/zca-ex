defmodule ZcaEx.Crypto.AesGcmTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Crypto.AesGcm

  describe "decrypt/2" do
    test "successfully decrypts valid AES-256-GCM data" do
      # Generate test data using Erlang crypto
      key = :crypto.strong_rand_bytes(32)
      iv = :crypto.strong_rand_bytes(16)
      aad = :crypto.strong_rand_bytes(16)
      plaintext = "Hello, WebSocket event data!"

      {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, aad, true)

      encrypted_data = iv <> aad <> ciphertext <> tag
      cipher_key_base64 = Base.encode64(key)

      assert {:ok, ^plaintext} = AesGcm.decrypt(cipher_key_base64, encrypted_data)
    end

    test "successfully decrypts AES-128-GCM data" do
      key = :crypto.strong_rand_bytes(16)
      iv = :crypto.strong_rand_bytes(16)
      aad = :crypto.strong_rand_bytes(16)
      plaintext = "Test message"

      {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_128_gcm, key, iv, plaintext, aad, true)

      encrypted_data = iv <> aad <> ciphertext <> tag
      cipher_key_base64 = Base.encode64(key)

      assert {:ok, ^plaintext} = AesGcm.decrypt(cipher_key_base64, encrypted_data)
    end

    test "decrypts empty plaintext" do
      key = :crypto.strong_rand_bytes(32)
      iv = :crypto.strong_rand_bytes(16)
      aad = :crypto.strong_rand_bytes(16)
      plaintext = ""

      {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, aad, true)

      encrypted_data = iv <> aad <> ciphertext <> tag
      cipher_key_base64 = Base.encode64(key)

      assert {:ok, ^plaintext} = AesGcm.decrypt(cipher_key_base64, encrypted_data)
    end

    test "decrypts JSON payload like WebSocket events" do
      key = :crypto.strong_rand_bytes(32)
      iv = :crypto.strong_rand_bytes(16)
      aad = :crypto.strong_rand_bytes(16)
      plaintext = ~s({"cmd":1,"data":{"userId":"12345","message":"hello"}})

      {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, aad, true)

      encrypted_data = iv <> aad <> ciphertext <> tag
      cipher_key_base64 = Base.encode64(key)

      assert {:ok, ^plaintext} = AesGcm.decrypt(cipher_key_base64, encrypted_data)
    end
  end

  describe "error handling" do
    test "returns error for invalid base64 key" do
      encrypted_data = :crypto.strong_rand_bytes(64)

      assert {:error, :invalid_base64_key} = AesGcm.decrypt("not-valid-base64!!!", encrypted_data)
    end

    test "returns error for invalid key size" do
      # 10 bytes is not a valid AES key size
      invalid_key = Base.encode64(:crypto.strong_rand_bytes(10))
      encrypted_data = :crypto.strong_rand_bytes(64)

      assert {:error, :invalid_key_size} = AesGcm.decrypt(invalid_key, encrypted_data)
    end

    test "returns error for data too short" do
      key = Base.encode64(:crypto.strong_rand_bytes(32))
      # Less than 48 bytes (16 IV + 16 AAD + 16 tag minimum)
      short_data = :crypto.strong_rand_bytes(47)

      assert {:error, :data_too_short} = AesGcm.decrypt(key, short_data)
    end

    test "returns error for tampered ciphertext" do
      key = :crypto.strong_rand_bytes(32)
      iv = :crypto.strong_rand_bytes(16)
      aad = :crypto.strong_rand_bytes(16)
      plaintext = "Original message"

      {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, aad, true)

      # Tamper with the ciphertext
      tampered_ciphertext = :crypto.strong_rand_bytes(byte_size(ciphertext))
      encrypted_data = iv <> aad <> tampered_ciphertext <> tag
      cipher_key_base64 = Base.encode64(key)

      assert {:error, :decryption_failed} = AesGcm.decrypt(cipher_key_base64, encrypted_data)
    end

    test "returns error for tampered tag" do
      key = :crypto.strong_rand_bytes(32)
      iv = :crypto.strong_rand_bytes(16)
      aad = :crypto.strong_rand_bytes(16)
      plaintext = "Original message"

      {ciphertext, _tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, aad, true)

      # Use a different tag
      tampered_tag = :crypto.strong_rand_bytes(16)
      encrypted_data = iv <> aad <> ciphertext <> tampered_tag
      cipher_key_base64 = Base.encode64(key)

      assert {:error, :decryption_failed} = AesGcm.decrypt(cipher_key_base64, encrypted_data)
    end

    test "returns error for wrong key" do
      key = :crypto.strong_rand_bytes(32)
      wrong_key = :crypto.strong_rand_bytes(32)
      iv = :crypto.strong_rand_bytes(16)
      aad = :crypto.strong_rand_bytes(16)
      plaintext = "Secret message"

      {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, aad, true)

      encrypted_data = iv <> aad <> ciphertext <> tag
      wrong_key_base64 = Base.encode64(wrong_key)

      assert {:error, :decryption_failed} = AesGcm.decrypt(wrong_key_base64, encrypted_data)
    end

    test "returns error for nil arguments" do
      assert {:error, :invalid_arguments} = AesGcm.decrypt(nil, <<1, 2, 3>>)
      assert {:error, :invalid_arguments} = AesGcm.decrypt("key", nil)
    end
  end
end
