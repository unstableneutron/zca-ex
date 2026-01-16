defmodule ZcaEx.ErrorTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Error

  describe "new/3" do
    test "creates error with defaults" do
      error = Error.new(:api, "Something went wrong")

      assert error.category == :api
      assert error.message == "Something went wrong"
      assert error.code == nil
      assert error.reason == nil
      assert error.retryable? == false
      assert error.details == %{}
    end

    test "creates error with all options" do
      error =
        Error.new(:network, "Connection failed",
          code: 500,
          reason: :econnrefused,
          retryable?: true,
          details: %{host: "localhost"}
        )

      assert error.category == :network
      assert error.message == "Connection failed"
      assert error.code == 500
      assert error.reason == :econnrefused
      assert error.retryable? == true
      assert error.details == %{host: "localhost"}
    end
  end

  describe "network/2" do
    test "creates network error with retryable? true by default" do
      error = Error.network("Connection timeout")

      assert error.category == :network
      assert error.message == "Connection timeout"
      assert error.retryable? == true
    end

    test "allows overriding retryable?" do
      error = Error.network("Permanent failure", retryable?: false)

      assert error.retryable? == false
    end
  end

  describe "api/3" do
    test "creates API error with code" do
      error = Error.api(1001, "Invalid token")

      assert error.category == :api
      assert error.code == 1001
      assert error.message == "Invalid token"
      assert error.retryable? == false
    end

    test "creates API error with nil code" do
      error = Error.api(nil, "Unknown API error")

      assert error.category == :api
      assert error.code == nil
      assert error.message == "Unknown API error"
    end
  end

  describe "crypto/2" do
    test "creates crypto error" do
      error = Error.crypto("Decryption failed", reason: :invalid_key)

      assert error.category == :crypto
      assert error.message == "Decryption failed"
      assert error.reason == :invalid_key
      assert error.retryable? == false
    end
  end

  describe "auth/2" do
    test "creates auth error" do
      error = Error.auth("Session expired")

      assert error.category == :auth
      assert error.message == "Session expired"
      assert error.retryable? == false
    end
  end

  describe "websocket/2" do
    test "creates websocket error with retryable? true by default" do
      error = Error.websocket("Connection lost")

      assert error.category == :websocket
      assert error.message == "Connection lost"
      assert error.retryable? == true
    end
  end

  describe "normalize/1" do
    test "returns ZcaEx.Error as-is" do
      original = Error.api(123, "Test error")
      assert Error.normalize(original) == original
    end

    test "converts Mint.TransportError to network error" do
      mint_error = %{__struct__: Mint.TransportError, reason: :econnrefused}
      error = Error.normalize(mint_error)

      assert error.category == :network
      assert error.message =~ "Transport error"
      assert error.reason == :econnrefused
      assert error.retryable? == true
    end

    test "converts Mint.HTTPError to network error" do
      mint_error = %{__struct__: Mint.HTTPError, reason: :invalid_response}
      error = Error.normalize(mint_error)

      assert error.category == :network
      assert error.message =~ "HTTP error"
      assert error.reason == :invalid_response
      assert error.retryable? == true
    end

    test "converts {:error, :timeout} to network error" do
      error = Error.normalize({:error, :timeout})

      assert error.category == :network
      assert error.message == "Connection timeout"
      assert error.reason == :timeout
      assert error.retryable? == true
    end

    test "converts {:error, :closed} to network error" do
      error = Error.normalize({:error, :closed})

      assert error.category == :network
      assert error.message == "Connection closed"
      assert error.reason == :closed
      assert error.retryable? == true
    end

    test "converts {:error, atom} to unknown error" do
      error = Error.normalize({:error, :something_else})

      assert error.category == :unknown
      assert error.message == "something_else"
      assert error.reason == :something_else
    end

    test "converts Jason.DecodeError to crypto error" do
      jason_error = %Jason.DecodeError{position: 0, token: nil, data: "invalid"}
      error = Error.normalize(jason_error)

      assert error.category == :crypto
      assert error.message =~ "JSON decode error"
      assert error.reason == jason_error
    end

    test "converts other exceptions to unknown error" do
      runtime_error = %RuntimeError{message: "Something broke"}
      error = Error.normalize(runtime_error)

      assert error.category == :unknown
      assert error.message == "Something broke"
      assert error.reason == runtime_error
    end

    test "converts arbitrary terms to unknown error" do
      error = Error.normalize("some string")

      assert error.category == :unknown
      assert error.message == "\"some string\""
      assert error.reason == "some string"
    end
  end

  describe "retryable?/1" do
    test "returns true for retryable errors" do
      error = Error.network("Timeout")
      assert Error.retryable?(error) == true
    end

    test "returns false for non-retryable errors" do
      error = Error.api(401, "Unauthorized")
      assert Error.retryable?(error) == false
    end

    test "returns false for non-Error terms" do
      assert Error.retryable?("not an error") == false
      assert Error.retryable?(nil) == false
      assert Error.retryable?({:error, :timeout}) == false
    end
  end

  describe "Exception protocol (message/1)" do
    test "formats message without code" do
      error = Error.auth("Session expired")
      assert Exception.message(error) == "[auth] Session expired"
    end

    test "formats message with code" do
      error = Error.api(1001, "Invalid token")
      assert Exception.message(error) == "[api:1001] Invalid token"
    end

    test "can be raised and caught" do
      assert_raise Error, "[api:500] Server error", fn ->
        raise Error.api(500, "Server error")
      end
    end
  end
end
