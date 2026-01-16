defmodule ZcaEx.Api.FactoryTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Factory
  alias ZcaEx.Crypto.AesCbc

  describe "encrypt_params/2 with base64 key" do
    setup do
      key = Base.encode64(:crypto.strong_rand_bytes(32))
      {:ok, key: key}
    end

    test "encrypts map params and returns {:ok, base64 string}", %{key: key} do
      params = %{"foo" => "bar", "num" => 123}

      assert {:ok, result} = Factory.encrypt_params(key, params)

      assert is_binary(result)
      assert String.match?(result, ~r/^[A-Za-z0-9+\/=]+$/)

      decrypted = AesCbc.decrypt_base64_key(key, result)
      assert {:ok, ^params} = Jason.decode(decrypted)
    end

    test "encrypts string params", %{key: key} do
      plaintext = "hello world"

      assert {:ok, result} = Factory.encrypt_params(key, plaintext)

      assert is_binary(result)
      decrypted = AesCbc.decrypt_base64_key(key, result)
      assert decrypted == plaintext
    end

    test "returns {:ok, ciphertext} for empty map", %{key: key} do
      assert {:ok, result} = Factory.encrypt_params(key, %{})
      assert is_binary(result)
    end
  end

  describe "encrypt_params_utf8/4" do
    @utf8_key "12345678901234567890123456789012"

    test "encrypts map params with hex output" do
      params = %{"test" => "value"}

      assert {:ok, result} = Factory.encrypt_params_utf8(@utf8_key, params, :hex, false)

      assert is_binary(result)
      assert String.match?(result, ~r/^[a-f0-9]+$/)

      decrypted = AesCbc.decrypt_utf8_key(@utf8_key, result, :hex)
      assert {:ok, ^params} = Jason.decode(decrypted)
    end

    test "encrypts with base64 output" do
      params = %{"foo" => "bar"}

      assert {:ok, result} = Factory.encrypt_params_utf8(@utf8_key, params, :base64, false)

      assert is_binary(result)
      assert String.match?(result, ~r/^[A-Za-z0-9+\/=]+$/)
    end

    test "encrypts with uppercase output" do
      params = %{"foo" => "bar"}

      assert {:ok, result} = Factory.encrypt_params_utf8(@utf8_key, params, :hex, true)

      assert result == String.upcase(result)
    end

    test "returns {:error, _} for empty string" do
      assert {:error, error} = Factory.encrypt_params_utf8(@utf8_key, "", :hex, false)
      assert error.message =~ "Failed to encrypt"
    end
  end

  describe "build_form_body/1" do
    test "builds form body from map" do
      params = %{"a" => "1", "b" => "2"}

      result = Factory.build_form_body(params)

      assert result =~ "a=1"
      assert result =~ "b=2"
      assert result =~ "&"
    end

    test "URL encodes special characters" do
      params = %{"name" => "hello world", "special" => "a=b&c"}

      result = Factory.build_form_body(params)

      assert result =~ "hello+world"
      assert result =~ "a%3Db%26c"
    end

    test "filters out nil values" do
      params = %{"keep" => "value", "drop" => nil}

      result = Factory.build_form_body(params)

      assert result =~ "keep=value"
      refute result =~ "drop"
    end

    test "handles empty map" do
      assert Factory.build_form_body(%{}) == ""
    end
  end

  describe "__using__/1" do
    defmodule TestApi do
      use ZcaEx.Api.Factory

      def test_encrypt(key, params) do
        encrypt_params(key, params)
      end
    end

    test "imports Factory functions" do
      key = Base.encode64(:crypto.strong_rand_bytes(32))
      assert {:ok, result} = TestApi.test_encrypt(key, %{"test" => "value"})
      assert is_binary(result)
    end
  end
end
