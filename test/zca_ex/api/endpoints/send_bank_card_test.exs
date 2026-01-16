defmodule ZcaEx.Api.Endpoints.SendBankCardTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.SendBankCard
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "chat" => ["https://chat.zalo.me"]
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

    bin_bank = %{
      bin: "970422",
      bankName: "MB Bank"
    }

    {:ok, session: session, credentials: credentials, bin_bank: bin_bank}
  end

  describe "build_params/6" do
    test "builds correct params for user thread", %{bin_bank: bin_bank} do
      params = SendBankCard.build_params(bin_bank, "123456789", "NGUYEN VAN A", "thread123", :user, 1234567890)

      assert params.binBank == bin_bank
      assert params.numAccBank == "123456789"
      assert params.nameAccBank == "NGUYEN VAN A"
      assert params.cliMsgId == "1234567890"
      assert params.tsMsg == 1234567890
      assert params.destUid == "thread123"
      assert params.destType == 0
    end

    test "builds correct params for group thread", %{bin_bank: bin_bank} do
      params = SendBankCard.build_params(bin_bank, "123456789", "test", "group123", :group, 1234567890)

      assert params.destType == 1
      assert params.destUid == "group123"
    end

    test "uppercases name_acc_bank", %{bin_bank: bin_bank} do
      params = SendBankCard.build_params(bin_bank, "123456789", "nguyen van a", "thread123", :user, 1234567890)

      assert params.nameAccBank == "NGUYEN VAN A"
    end

    test "uses --- for empty name_acc_bank", %{bin_bank: bin_bank} do
      params = SendBankCard.build_params(bin_bank, "123456789", "", "thread123", :user, 1234567890)

      assert params.nameAccBank == "---"
    end

    test "uses --- for nil name_acc_bank", %{bin_bank: bin_bank} do
      params = SendBankCard.build_params(bin_bank, "123456789", nil, "thread123", :user, 1234567890)

      assert params.nameAccBank == "---"
    end
  end

  describe "build_url/2" do
    test "builds correct URL", %{session: session} do
      url = SendBankCard.build_url("https://chat.zalo.me", session)

      assert url =~ "https://chat.zalo.me/api/transfer/card"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "send/7 validation" do
    test "returns error for nil thread_id", %{session: session, credentials: credentials, bin_bank: bin_bank} do
      result = SendBankCard.send(session, credentials, nil, :user, bin_bank, "123456789")

      assert {:error, error} = result
      assert error.message == "thread_id is required"
      assert error.code == :invalid_input
    end

    test "returns error for empty thread_id", %{session: session, credentials: credentials, bin_bank: bin_bank} do
      result = SendBankCard.send(session, credentials, "", :user, bin_bank, "123456789")

      assert {:error, error} = result
      assert error.message == "thread_id cannot be empty"
      assert error.code == :invalid_input
    end

    test "returns error for invalid thread_type", %{session: session, credentials: credentials, bin_bank: bin_bank} do
      result = SendBankCard.send(session, credentials, "thread123", :invalid, bin_bank, "123456789")

      assert {:error, error} = result
      assert error.message == "thread_type must be :user or :group"
      assert error.code == :invalid_input
    end

    test "returns error for nil bin_bank", %{session: session, credentials: credentials} do
      result = SendBankCard.send(session, credentials, "thread123", :user, nil, "123456789")

      assert {:error, error} = result
      assert error.message == "bin_bank is required"
      assert error.code == :invalid_input
    end

    test "returns error for empty bin_bank", %{session: session, credentials: credentials} do
      result = SendBankCard.send(session, credentials, "thread123", :user, %{}, "123456789")

      assert {:error, error} = result
      assert error.message == "bin_bank cannot be empty"
      assert error.code == :invalid_input
    end

    test "returns error for non-map bin_bank", %{session: session, credentials: credentials} do
      result = SendBankCard.send(session, credentials, "thread123", :user, "not a map", "123456789")

      assert {:error, error} = result
      assert error.message == "bin_bank must be a map"
      assert error.code == :invalid_input
    end

    test "returns error for nil num_acc_bank", %{session: session, credentials: credentials, bin_bank: bin_bank} do
      result = SendBankCard.send(session, credentials, "thread123", :user, bin_bank, nil)

      assert {:error, error} = result
      assert error.message == "num_acc_bank is required"
      assert error.code == :invalid_input
    end

    test "returns error for empty num_acc_bank", %{session: session, credentials: credentials, bin_bank: bin_bank} do
      result = SendBankCard.send(session, credentials, "thread123", :user, bin_bank, "")

      assert {:error, error} = result
      assert error.message == "num_acc_bank cannot be empty"
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials, bin_bank: bin_bank} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = SendBankCard.send(session_no_service, credentials, "thread123", :user, bin_bank, "123456789")

      assert {:error, error} = result
      assert error.message =~ "chat service URL not found"
      assert error.code == :service_not_found
    end
  end
end
