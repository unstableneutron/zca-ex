defmodule ZcaEx.Crypto.AesCbcTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Crypto.AesCbc

  @fixtures_path "test/fixtures/crypto_fixtures.json"

  setup_all do
    fixtures = @fixtures_path |> File.read!() |> Jason.decode!()
    {:ok, fixtures: fixtures}
  end

  describe "encrypt_utf8_key/4" do
    test "matches JS implementation for all fixtures", %{fixtures: fixtures} do
      for fixture <- fixtures["aes_cbc"] do
        %{
          "key" => key,
          "message" => message,
          "type" => type,
          "uppercase" => uppercase,
          "output" => expected
        } = fixture

        output_format = String.to_atom(type)
        result = AesCbc.encrypt_utf8_key(key, message, output_format, uppercase)

        assert result == expected,
               "Failed for message: #{inspect(message)}, expected: #{expected}, got: #{result}"
      end
    end

    test "returns nil for empty message" do
      assert AesCbc.encrypt_utf8_key("key", "", :hex, false) == nil
      assert AesCbc.encrypt_utf8_key("key", nil, :hex, false) == nil
    end
  end

  describe "decrypt_base64_key/2" do
    test "matches JS implementation for all fixtures", %{fixtures: fixtures} do
      for fixture <- fixtures["aes_cbc_decrypt"] do
        %{
          "secretKey" => secret_key,
          "encrypted" => encrypted,
          "plaintext" => expected_plaintext
        } = fixture

        result = AesCbc.decrypt_base64_key(secret_key, encrypted)

        assert result == expected_plaintext,
               "Failed decryption, expected: #{expected_plaintext}, got: #{result}"
      end
    end
  end

  describe "pkcs7_pad/1 and pkcs7_unpad/1" do
    test "padding is reversible" do
      original = "test message"
      padded = AesCbc.pkcs7_pad(original)
      unpadded = AesCbc.pkcs7_unpad(padded)
      assert unpadded == original
    end

    test "padding adds correct number of bytes" do
      # 11 bytes -> needs 5 bytes padding to reach 16
      data = "hello world"
      padded = AesCbc.pkcs7_pad(data)
      assert byte_size(padded) == 16
      assert :binary.last(padded) == 5
    end

    test "full block gets 16 bytes padding" do
      data = "1234567890123456"
      padded = AesCbc.pkcs7_pad(data)
      assert byte_size(padded) == 32
      assert :binary.last(padded) == 16
    end
  end
end
