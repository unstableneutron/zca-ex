defmodule ZcaEx.Api.Endpoints.UpdateHiddenConversPinTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateHiddenConversPin
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "conversation" => ["https://conversation.zalo.me"]
      },
      api_type: 30,
      api_version: 645
    }

    {:ok, credentials} =
      Credentials.new(
        imei: "test-imei-12345",
        user_agent: "Mozilla/5.0 Test",
        cookies: [%{"name" => "test", "value" => "cookie"}],
        language: "vi"
      )

    {:ok, session: session, credentials: credentials}
  end

  describe "validate_pin/1" do
    test "returns :ok for valid 4-digit PIN" do
      assert :ok == UpdateHiddenConversPin.validate_pin("1234")
      assert :ok == UpdateHiddenConversPin.validate_pin("0000")
      assert :ok == UpdateHiddenConversPin.validate_pin("9999")
    end

    test "returns error for non-4-digit string" do
      assert {:error, error} = UpdateHiddenConversPin.validate_pin("123")
      assert error.message =~ "4-digit"
      assert error.code == :invalid_input

      assert {:error, _} = UpdateHiddenConversPin.validate_pin("12345")
      assert {:error, _} = UpdateHiddenConversPin.validate_pin("")
    end

    test "returns error for non-numeric string" do
      assert {:error, error} = UpdateHiddenConversPin.validate_pin("abcd")
      assert error.code == :invalid_input

      assert {:error, _} = UpdateHiddenConversPin.validate_pin("12ab")
    end

    test "returns error for non-string" do
      assert {:error, error} = UpdateHiddenConversPin.validate_pin(1234)
      assert error.message =~ "string"
      assert error.code == :invalid_input

      assert {:error, _} = UpdateHiddenConversPin.validate_pin(nil)
      assert {:error, _} = UpdateHiddenConversPin.validate_pin([1, 2, 3, 4])
    end
  end

  describe "encrypt_pin/1" do
    test "returns MD5 hash in lowercase hex" do
      # MD5("1234") = 81dc9bdb52d04dc20036dbd8313ed055
      assert UpdateHiddenConversPin.encrypt_pin("1234") == "81dc9bdb52d04dc20036dbd8313ed055"
    end

    test "returns consistent hash for same input" do
      hash1 = UpdateHiddenConversPin.encrypt_pin("0000")
      hash2 = UpdateHiddenConversPin.encrypt_pin("0000")
      assert hash1 == hash2
    end

    test "returns different hash for different input" do
      hash1 = UpdateHiddenConversPin.encrypt_pin("1234")
      hash2 = UpdateHiddenConversPin.encrypt_pin("4321")
      assert hash1 != hash2
    end

    test "hash is 32 characters (128 bits in hex)" do
      hash = UpdateHiddenConversPin.encrypt_pin("5678")
      assert String.length(hash) == 32
      assert Regex.match?(~r/^[0-9a-f]{32}$/, hash)
    end
  end

  describe "build_params/2" do
    test "builds correct params" do
      params = UpdateHiddenConversPin.build_params("encrypted_pin_hash", "test-imei")

      assert params.new_pin == "encrypted_pin_hash"
      assert params.imei == "test-imei"
    end
  end

  describe "build_base_url/1" do
    test "builds correct base URL", %{session: session} do
      assert {:ok, url} = UpdateHiddenConversPin.build_base_url(session)

      assert url =~ "https://conversation.zalo.me/api/hiddenconvers/update-pin"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"conversation" => "https://conversation2.zalo.me"}}
      assert {:ok, url} = UpdateHiddenConversPin.build_base_url(session)

      assert url =~ "https://conversation2.zalo.me/api/hiddenconvers/update-pin"
    end

    test "returns error when service URL not found", %{session: session} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert {:error, error} = UpdateHiddenConversPin.build_base_url(session_no_service)
      assert error.message == "conversation service URL not found"
      assert error.code == :service_not_found
    end
  end

  describe "build_url/3" do
    test "builds URL with encrypted params", %{session: session} do
      url =
        UpdateHiddenConversPin.build_url(
          "https://conversation.zalo.me",
          "encryptedParams123",
          session
        )

      assert url =~ "https://conversation.zalo.me/api/hiddenconvers/update-pin"
      assert url =~ "params=encryptedParams123"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/3 validation" do
    test "returns error for invalid PIN format", %{session: session, credentials: credentials} do
      assert {:error, error} = UpdateHiddenConversPin.call(session, credentials, "123")
      assert error.code == :invalid_input
    end

    test "returns error for non-string PIN", %{session: session, credentials: credentials} do
      assert {:error, error} = UpdateHiddenConversPin.call(session, credentials, 1234)
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert {:error, error} =
               UpdateHiddenConversPin.call(session_no_service, credentials, "1234")

      assert error.message == "conversation service URL not found"
      assert error.code == :service_not_found
    end
  end
end
