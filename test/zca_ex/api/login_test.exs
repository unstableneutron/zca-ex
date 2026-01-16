defmodule ZcaEx.Api.LoginTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Account.Credentials
  alias ZcaEx.Crypto.{ParamsEncryptor, SignKey}

  describe "encrypted params building" do
    test "builds encrypted login params with correct structure" do
      {:ok, creds} =
        Credentials.new(
          imei: "test-imei-12345",
          user_agent: "Mozilla/5.0 Test",
          cookies: []
        )

      ts = 1_704_067_200_000
      encryptor = ParamsEncryptor.new(creds.api_type, creds.imei, ts)
      encrypt_key = ParamsEncryptor.get_encrypt_key(encryptor)
      encrypted_params = ParamsEncryptor.get_params(encryptor)

      assert String.length(encrypt_key) == 32
      assert is_binary(encrypted_params.zcid)
      assert is_binary(encrypted_params.zcid_ext)
      assert encrypted_params.enc_ver == "v2"
    end

    test "encrypts data payload correctly" do
      {:ok, creds} =
        Credentials.new(
          imei: "test-imei-12345",
          user_agent: "Mozilla/5.0 Test",
          cookies: []
        )

      ts = 1_704_067_200_000

      data = %{
        "computer_name" => "Web",
        "imei" => creds.imei,
        "language" => creds.language,
        "ts" => ts
      }

      encryptor = ParamsEncryptor.new(creds.api_type, creds.imei, ts)
      encrypt_key = ParamsEncryptor.get_encrypt_key(encryptor)

      json_data = Jason.encode!(data)
      encoded_data = ParamsEncryptor.encode_aes(encrypt_key, json_data, :base64, false)

      assert is_binary(encoded_data)
      assert String.length(encoded_data) > 0
    end

    test "generates signkey for login params" do
      params = %{
        zcid: "test-zcid",
        zcid_ext: "abc123",
        enc_ver: "v2",
        params: "encrypted-data",
        type: 30,
        client_version: 665
      }

      signkey = SignKey.generate("getlogininfo", params)

      assert is_binary(signkey)
      assert String.length(signkey) == 32
      assert signkey =~ ~r/^[a-f0-9]{32}$/
    end

    test "generates signkey for server info params" do
      params = %{
        "imei" => "test-imei",
        "type" => 30,
        "client_version" => 665,
        "computer_name" => "Web"
      }

      signkey = SignKey.generate("getserverinfo", params)

      assert is_binary(signkey)
      assert String.length(signkey) == 32
    end
  end

  describe "credentials validation" do
    test "creates valid credentials" do
      {:ok, creds} =
        Credentials.new(
          imei: "test-imei",
          user_agent: "Mozilla/5.0",
          cookies: []
        )

      assert creds.imei == "test-imei"
      assert creds.user_agent == "Mozilla/5.0"
      assert creds.cookies == []
      assert creds.language == "vi"
      assert creds.api_type == 30
      assert creds.api_version == 665
    end

    test "creates credentials with custom values" do
      {:ok, creds} =
        Credentials.new(
          imei: "test-imei",
          user_agent: "Mozilla/5.0",
          cookies: [%{"name" => "test", "value" => "cookie"}],
          language: "en",
          api_type: 31,
          api_version: 700
        )

      assert creds.language == "en"
      assert creds.api_type == 31
      assert creds.api_version == 700
    end

    test "returns error for missing imei" do
      assert {:error, {:missing_required, :imei}} =
               Credentials.new(
                 user_agent: "Mozilla/5.0",
                 cookies: []
               )
    end

    test "returns error for missing user_agent" do
      assert {:error, {:missing_required, :user_agent}} =
               Credentials.new(
                 imei: "test-imei",
                 cookies: []
               )
    end

    test "returns error for missing cookies" do
      assert {:error, {:missing_required, :cookies}} =
               Credentials.new(
                 imei: "test-imei",
                 user_agent: "Mozilla/5.0"
               )
    end

    test "normalizes cookies from map with cookies key" do
      cookies = [%{"name" => "test"}]

      {:ok, creds} =
        Credentials.new(
          imei: "test-imei",
          user_agent: "Mozilla/5.0",
          cookies: %{"cookies" => cookies}
        )

      assert creds.cookies == cookies
    end
  end
end
