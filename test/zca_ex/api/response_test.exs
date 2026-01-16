defmodule ZcaEx.Api.ResponseTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Response
  alias ZcaEx.HTTP.Response, as: HTTPResponse
  alias ZcaEx.Crypto.AesCbc
  alias ZcaEx.Error

  describe "parse/2" do
    setup do
      key_bytes = :crypto.strong_rand_bytes(32)
      secret_key = Base.encode64(key_bytes)
      {:ok, secret_key: secret_key, key_bytes: key_bytes}
    end

    test "parses successful encrypted response", %{secret_key: secret_key, key_bytes: key_bytes} do
      inner_data = %{"user_id" => "123", "name" => "Test"}
      encrypted_data = AesCbc.encrypt_base64_key(key_bytes, Jason.encode!(inner_data))

      body =
        Jason.encode!(%{
          "error_code" => 0,
          "data" => encrypted_data
        })

      http_response = %HTTPResponse{status: 200, headers: [], body: body}

      assert {:ok, ^inner_data} = Response.parse(http_response, secret_key)
    end

    test "handles tuple input", %{secret_key: secret_key, key_bytes: key_bytes} do
      inner_data = %{"result" => "ok"}
      encrypted_data = AesCbc.encrypt_base64_key(key_bytes, Jason.encode!(inner_data))

      body =
        Jason.encode!(%{
          "error_code" => 0,
          "data" => encrypted_data
        })

      http_response = %HTTPResponse{status: 200, headers: [], body: body}

      assert {:ok, ^inner_data} = Response.parse({:ok, http_response}, secret_key)
    end

    test "returns error for HTTP failure", %{secret_key: secret_key} do
      http_response = %HTTPResponse{status: 500, headers: [], body: ""}

      assert {:error, %Error{code: 500}} = Response.parse(http_response, secret_key)
    end

    test "returns error for request error", %{secret_key: secret_key} do
      assert {:error, %Error{message: msg}} = Response.parse({:error, :timeout}, secret_key)
      assert msg =~ "timeout"
    end

    test "returns error for outer error code", %{secret_key: secret_key} do
      body =
        Jason.encode!(%{
          "error_code" => 401,
          "error_message" => "Unauthorized"
        })

      http_response = %HTTPResponse{status: 200, headers: [], body: body}

      assert {:error, %Error{code: 401, message: "Unauthorized"}} =
               Response.parse(http_response, secret_key)
    end

    test "returns error for inner error code", %{secret_key: secret_key, key_bytes: key_bytes} do
      inner_data = %{"error_code" => 500, "error_message" => "Internal error"}
      encrypted_data = AesCbc.encrypt_base64_key(key_bytes, Jason.encode!(inner_data))

      body =
        Jason.encode!(%{
          "error_code" => 0,
          "data" => encrypted_data
        })

      http_response = %HTTPResponse{status: 200, headers: [], body: body}

      assert {:error, %Error{code: 500, message: "Internal error"}} =
               Response.parse(http_response, secret_key)
    end

    test "handles unencrypted data field", %{secret_key: secret_key} do
      inner_data = %{"foo" => "bar"}

      body =
        Jason.encode!(%{
          "error_code" => 0,
          "data" => inner_data
        })

      http_response = %HTTPResponse{status: 200, headers: [], body: body}

      assert {:ok, ^inner_data} = Response.parse(http_response, secret_key)
    end

    test "returns error for invalid JSON", %{secret_key: secret_key} do
      http_response = %HTTPResponse{status: 200, headers: [], body: "not json"}

      assert {:error, %Error{message: "Failed to decode JSON response"}} =
               Response.parse(http_response, secret_key)
    end
  end

  describe "parse_unencrypted/1" do
    test "parses successful response without decryption" do
      data = %{"result" => "success"}

      body =
        Jason.encode!(%{
          "error_code" => 0,
          "data" => data
        })

      http_response = %HTTPResponse{status: 200, headers: [], body: body}

      assert {:ok, ^data} = Response.parse_unencrypted(http_response)
    end

    test "handles response without data field" do
      body =
        Jason.encode!(%{
          "error_code" => 0,
          "message" => "ok"
        })

      http_response = %HTTPResponse{status: 200, headers: [], body: body}

      result = Response.parse_unencrypted(http_response)
      assert {:ok, response} = result
      assert response["error_code"] == 0
    end

    test "returns error for error code" do
      body =
        Jason.encode!(%{
          "error_code" => 403,
          "error_message" => "Forbidden"
        })

      http_response = %HTTPResponse{status: 200, headers: [], body: body}

      assert {:error, %Error{code: 403, message: "Forbidden"}} =
               Response.parse_unencrypted(http_response)
    end
  end

  describe "check_error/1" do
    test "returns :ok for success" do
      assert :ok = Response.check_error(%{"error_code" => 0})
    end

    test "returns error for non-zero error code" do
      assert {:error, %Error{code: 123, message: "Error"}} =
               Response.check_error(%{"error_code" => 123, "error_message" => "Error"})
    end

    test "uses default message if none provided" do
      assert {:error, %Error{code: 456, message: "Unknown error"}} =
               Response.check_error(%{"error_code" => 456})
    end
  end

  describe "decrypt_data_utf8/3" do
    @utf8_key "12345678901234567890123456789012"

    test "decrypts base64 encoded data" do
      inner = %{"test" => "value"}
      encrypted = AesCbc.encrypt_utf8_key(@utf8_key, Jason.encode!(inner), :base64, false)

      response = %{"data" => encrypted}

      assert {:ok, ^inner} = Response.decrypt_data_utf8(response, @utf8_key, :base64)
    end

    test "decrypts hex encoded data" do
      inner = %{"foo" => "bar"}
      encrypted = AesCbc.encrypt_utf8_key(@utf8_key, Jason.encode!(inner), :hex, false)

      response = %{"data" => encrypted}

      assert {:ok, ^inner} = Response.decrypt_data_utf8(response, @utf8_key, :hex)
    end

    test "handles map data field" do
      data = %{"already" => "decoded"}
      response = %{"data" => data}

      assert {:ok, ^data} = Response.decrypt_data_utf8(response, @utf8_key, :base64)
    end
  end
end
