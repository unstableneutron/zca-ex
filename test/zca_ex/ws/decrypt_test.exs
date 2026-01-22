defmodule ZcaEx.WS.DecryptTest do
  @moduledoc """
  Tests for WebSocket event decryption and gzip decompression.

  Data captured from live WebSocket session:
  - Cipher key from handshake
  - Encrypted message payloads with encrypt=2
  """
  use ExUnit.Case, async: true

  alias ZcaEx.Crypto.AesGcm

  # Captured from live session
  @cipher_key "A7a6kbaDlhfWrevHBlO2UQ=="

  # Captured encrypted messages (encrypt=2)
  @encrypted_data_1 "jtXZbxWtsjkXj6bpFnDhRlTgEVsODqiCRICa9S4sho//FwR4ISpPY5xz/rXKUjyrzEtQddTu8aXRi9fJFnE2uFq50jR9CF10LEYqaWjEdJWdnzHZ52n/yPjzQfEO+Cq1WMjUlefHIEyQbsPsnJ4ziXtVx2Mouw2MtNy3mbQJGyLG6r2GDJoXIuIPMZ09XCXsIRAS3qT/nR7WTzQW/NCpjpzFNmdhstXOTi3qNul5cyL79IUzmySmFA2fmGVnBuMnbKbv1kjklb+7A5mbMA6cdabVJm5rUiaUiaI7KIMABi7nUMvNnUDDGH+nbPVTXqICNgevSOKUBOz+J1nD8I9RODldgVe2xvyuZviX9NSbEimWI0sPUFdYQZ7oP316Zcxm3OmTgCCA9upZm+4Owm+u56Cr4a2qBYBk1Hy8O1rVvZbZZj3vsZ1gGRAxT4TiFHGr52XxGk07aI3ODyf5MR1Y3LNFMpoElnksrkQOedCS28gkFIQkKyTa1Kobjj02L5T09cQosnsIIhFtKjzN18V14QUFApOoDqyhEGEaV32dJPlr6ExJqLikxI3i9VMbY1znTHGT3NQRumitUgnKB2JOHR5CbtXDKJumATZv3XIlge/99IDASkCrLri/UTIckeOMU9LBx6qB/MwHcrt/nFNG/Y37yWZXlt2Cw2cqHfAgFScAGC+dkoNHpsB14utqCefqDRo+pBkRKMsWnrrCQ5HcVk1sOwpmehFLOwg8FXdXKQGu8DBzgkXlHGoj9xQX3Pmg9zcmM0SZ18LBYtZTiw=="

  @encrypted_data_2 "8STpVsyPp2/RefYuO6XZirmOYs1dnfbeT5Jirm/5boOlGLQXXlJAkTqXqhn2dhOBTAozW+jjoHzfREeI50ycQJjT/43uV+PgqANuSA9XonrEJV/p9Nkbu2ep5Fhl9z1AOpDRKRRGoX+2KdFdd/asXv0qxqrgB9srWPRa8iBdcI7+AUBw5JCzA61s9/mYSIEV3M01au3VndNnrbyLsv/E4/fnGfCuPYsTf/0GyFnGI5zcbzrtNcILwzgJoKoDNXtH7P0HFmm81Q1iTuh/Tqfjvb39/cTgWysbRKHYy+vjjYhp02TbW2o1A3qeKIFFoAQKJPyHhMhMl7/KYMZxZCJuFashxcCgTs8itxA/gf8f6b6EpjJOFws94lpdnINNHzRaXjXpW9Fwa+5VSUjJwr8Cgk7woCYRoIF4zjLCdRr6DpZtaRRqro8NEtC/MVc8SSb81QuHSnpSxCidq1KrzyFSm9hgbi1dtaUVtbtcNQiJCU6CkRWdALPdQUwuxmbjjtMfA3z5llyXYYE9ad0K7lll5gUBfZab8CnfVBf2AwS0Qq9mp84IEknxfpG+bR6sqcMEsJ7e+x+hehWvcxb7WO392aR5Js151hRguv07t33n4sZLRl9aNlvGi6CMuA4Bbp7mQf7lIuFz1EJQFpX87wy0jDV9qpxwS77HoD3f9MPOYmJa0kz+ABEe0Lu7fBTSdeSQ8tWnE22xQTAqXAE="

  describe "maybe_decompress/2 gzip decompression" do
    test "decompresses gzip data (encrypt type 1 or 2)" do
      # Create gzip compressed test data
      original = ~s({"event":"test","data":"hello world"})
      compressed = :zlib.gzip(original)

      # Verify magic bytes
      <<0x1F, 0x8B, _rest::binary>> = compressed

      # Test decompression
      result = maybe_decompress(compressed, 2)
      assert {:ok, ^original} = result
    end

    test "decompresses gzip data with encrypt type 1" do
      original = "test payload data"
      compressed = :zlib.gzip(original)

      result = maybe_decompress(compressed, 1)
      assert {:ok, ^original} = result
    end

    test "passes through data unchanged for other encrypt types" do
      data = "uncompressed data"

      assert {:ok, ^data} = maybe_decompress(data, 0)
      assert {:ok, ^data} = maybe_decompress(data, 3)
      assert {:ok, ^data} = maybe_decompress(data, nil)
    end

    test "handles invalid gzip data gracefully" do
      invalid_data = "not gzip data at all"

      result = maybe_decompress(invalid_data, 2)
      assert {:error, {:decompress_failed, _}} = result
    end
  end

  describe "full decrypt flow with real captured data" do
    test "decrypts and decompresses encrypt=2 data (sample 1) using decrypt/2" do
      # Step 1: URL decode (base64 doesn't usually need it, but protocol may URL-encode)
      url_decoded = URI.decode(@encrypted_data_1)

      # Step 2: Base64 decode
      {:ok, encrypted_binary} = Base.decode64(url_decoded)
      assert byte_size(encrypted_binary) >= 48

      # Step 3: AES-GCM decrypt (using base64 key)
      {:ok, decrypted} = AesGcm.decrypt(@cipher_key, encrypted_binary)

      # Verify it's gzip compressed (magic bytes 1F 8B)
      assert <<0x1F, 0x8B, _rest::binary>> = decrypted

      # Step 4: Gzip decompress
      {:ok, decompressed} = maybe_decompress(decrypted, 2)

      # Should be valid JSON
      assert {:ok, json} = Jason.decode(decompressed)
      assert is_map(json)
    end

    test "decrypts and decompresses encrypt=2 data (sample 1) using decrypt_with_key/2" do
      # Pre-decode the key (as Connection module now does)
      {:ok, decoded_key} = Base.decode64(@cipher_key)

      url_decoded = URI.decode(@encrypted_data_1)
      {:ok, encrypted_binary} = Base.decode64(url_decoded)

      # Decrypt with pre-decoded binary key
      {:ok, decrypted} = AesGcm.decrypt_with_key(decoded_key, encrypted_binary)

      assert <<0x1F, 0x8B, _rest::binary>> = decrypted

      {:ok, decompressed} = maybe_decompress(decrypted, 2)
      assert {:ok, json} = Jason.decode(decompressed)
      assert is_map(json)
    end

    test "decrypts and decompresses encrypt=2 data (sample 2)" do
      url_decoded = URI.decode(@encrypted_data_2)
      {:ok, encrypted_binary} = Base.decode64(url_decoded)

      {:ok, decrypted} = AesGcm.decrypt(@cipher_key, encrypted_binary)

      # Verify gzip magic bytes
      assert <<0x1F, 0x8B, _rest::binary>> = decrypted

      # Decompress
      {:ok, decompressed} = maybe_decompress(decrypted, 2)

      # Should be valid JSON
      assert {:ok, json} = Jason.decode(decompressed)
      assert is_map(json)
    end
  end

  describe "gzip header analysis" do
    test "validates gzip header structure" do
      url_decoded = URI.decode(@encrypted_data_1)
      {:ok, encrypted_binary} = Base.decode64(url_decoded)
      {:ok, decrypted} = AesGcm.decrypt(@cipher_key, encrypted_binary)

      # Gzip header: 1F 8B 08 [flags] [mtime 4 bytes] [xfl] [os]
      assert <<0x1F, 0x8B, 0x08, flags, _mtime::binary-size(4), _xfl, _os, _rest::binary>> =
               decrypted

      # flags=0 means no extra fields (FTEXT, FHCRC, FEXTRA, FNAME, FCOMMENT all clear)
      assert flags == 0
    end

    test "both zlib.gunzip and inflate with wbits=31 work" do
      url_decoded = URI.decode(@encrypted_data_1)
      {:ok, encrypted_binary} = Base.decode64(url_decoded)
      {:ok, decrypted} = AesGcm.decrypt(@cipher_key, encrypted_binary)

      # Method 1: zlib.gunzip
      gunzip_result = :zlib.gunzip(decrypted)
      assert is_binary(gunzip_result)

      # Method 2: inflate with window bits 31 (15 + 16 for gzip)
      z = :zlib.open()
      :ok = :zlib.inflateInit(z, 31)
      inflate_result = :zlib.inflate(z, decrypted) |> IO.iodata_to_binary()
      :zlib.inflateEnd(z)
      :zlib.close(z)

      assert is_binary(inflate_result)

      # Both should produce the same result
      assert gunzip_result == inflate_result
    end
  end

  # Replicate the maybe_decompress function from Connection module for testing
  defp maybe_decompress(data, encrypt_type) when encrypt_type in [1, 2] do
    try do
      decompressed = :zlib.gunzip(data)
      {:ok, decompressed}
    rescue
      _ ->
        try do
          z = :zlib.open()
          :ok = :zlib.inflateInit(z, 31)
          decompressed = :zlib.inflate(z, data) |> IO.iodata_to_binary()
          :zlib.inflateEnd(z)
          :zlib.close(z)
          {:ok, decompressed}
        rescue
          e -> {:error, {:decompress_failed, e}}
        end
    end
  end

  defp maybe_decompress(data, _encrypt_type), do: {:ok, data}
end
