defmodule ZcaEx.Crypto.ParamsEncryptorTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Crypto.ParamsEncryptor

  @fixtures_path "test/fixtures/crypto_fixtures.json"

  setup_all do
    fixtures = @fixtures_path |> File.read!() |> Jason.decode!()
    {:ok, fixtures: fixtures}
  end

  describe "new/4 with fixed zcid_ext" do
    test "generates correct ZCID and encrypt key", %{fixtures: fixtures} do
      for fixture <- fixtures["params_encryptor"] do
        %{
          "type" => type,
          "imei" => imei,
          "firstLaunchTime" => first_launch_time,
          "zcid_ext" => zcid_ext,
          "expected_zcid" => expected_zcid,
          "expected_encrypt_key" => expected_encrypt_key
        } = fixture

        encryptor = ParamsEncryptor.new(type, imei, first_launch_time, zcid_ext)

        params = ParamsEncryptor.get_params(encryptor)
        assert params.zcid == expected_zcid,
               "ZCID mismatch, expected: #{expected_zcid}, got: #{params.zcid}"

        assert params.zcid_ext == zcid_ext
        assert params.enc_ver == "v2"

        encrypt_key = ParamsEncryptor.get_encrypt_key(encryptor)
        assert encrypt_key == expected_encrypt_key,
               "Encrypt key mismatch, expected: #{expected_encrypt_key}, got: #{encrypt_key}"
      end
    end
  end

  describe "new/3 with random zcid_ext" do
    test "generates valid encryptor" do
      encryptor = ParamsEncryptor.new(30, "test-imei", 1_704_067_200_000)

      params = ParamsEncryptor.get_params(encryptor)
      assert is_binary(params.zcid)
      assert String.length(params.zcid) > 0
      assert is_binary(params.zcid_ext)
      assert String.length(params.zcid_ext) >= 6
      assert String.length(params.zcid_ext) <= 12
      assert params.enc_ver == "v2"

      encrypt_key = ParamsEncryptor.get_encrypt_key(encryptor)
      assert is_binary(encrypt_key)
      assert String.length(encrypt_key) == 32
    end
  end

  describe "encode_aes/4" do
    test "encrypts correctly", %{fixtures: fixtures} do
      [fixture | _] = fixtures["aes_cbc"]
      %{
        "key" => key,
        "message" => message,
        "type" => type,
        "uppercase" => uppercase,
        "output" => expected
      } = fixture

      result = ParamsEncryptor.encode_aes(key, message, String.to_atom(type), uppercase)
      assert result == expected
    end
  end
end
