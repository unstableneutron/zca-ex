defmodule ZcaEx.Api.Factory do
  @moduledoc """
  Macro for generating API endpoints with common patterns:
  - AES encryption of params
  - Signed requests
  - Response decryption
  - Error handling
  """

  defmacro __using__(_opts) do
    quote do
      import ZcaEx.Api.Factory

      alias ZcaEx.Account.{Session, Credentials}
      alias ZcaEx.Crypto.AesCbc
      alias ZcaEx.HTTP.AccountClient
      alias ZcaEx.Api.{Response, Url}
    end
  end

  alias ZcaEx.Crypto.AesCbc

  @doc """
  Encrypt params for API request using AES-CBC with base64-encoded key.
  Returns base64-encoded ciphertext.
  """
  @spec encrypt_params(String.t(), map() | String.t()) ::
          {:ok, String.t()} | {:error, ZcaEx.Error.t()}
  def encrypt_params(secret_key, params) when is_map(params) do
    case Jason.encode(params) do
      {:ok, json} -> encrypt_params(secret_key, json)
      {:error, reason} -> {:error, %ZcaEx.Error{message: "Failed to encode params: #{inspect(reason)}", code: nil}}
    end
  end

  def encrypt_params(secret_key, plaintext) when is_binary(plaintext) do
    case Base.decode64(secret_key) do
      {:ok, key} ->
        case AesCbc.encrypt_base64_key(key, plaintext) do
          ciphertext when is_binary(ciphertext) -> {:ok, ciphertext}
          nil -> {:error, %ZcaEx.Error{message: "Failed to encrypt params", code: nil}}
        end

      :error ->
        {:error, %ZcaEx.Error{message: "Invalid secret key encoding", code: nil}}
    end
  end

  @doc """
  Encrypt params using a UTF-8 string key (32 chars).
  Returns hex or base64 encoded ciphertext.
  """
  @spec encrypt_params_utf8(String.t(), map() | String.t(), :hex | :base64, boolean()) ::
          {:ok, String.t()} | {:error, ZcaEx.Error.t()}
  def encrypt_params_utf8(key, params, output_format \\ :base64, uppercase? \\ false)

  def encrypt_params_utf8(key, params, output_format, uppercase?) when is_map(params) do
    case Jason.encode(params) do
      {:ok, json} -> encrypt_params_utf8(key, json, output_format, uppercase?)
      {:error, reason} -> {:error, %ZcaEx.Error{message: "Failed to encode params: #{inspect(reason)}", code: nil}}
    end
  end

  def encrypt_params_utf8(key, plaintext, output_format, uppercase?) when is_binary(plaintext) do
    case AesCbc.encrypt_utf8_key(key, plaintext, output_format, uppercase?) do
      ciphertext when is_binary(ciphertext) -> {:ok, ciphertext}
      nil -> {:error, %ZcaEx.Error{message: "Failed to encrypt params", code: nil}}
    end
  end

  @doc """
  Build form-encoded body from params map.
  """
  @spec build_form_body(map()) :: String.t()
  def build_form_body(params) when is_map(params) do
    params
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} -> "#{URI.encode_www_form(to_string(k))}=#{URI.encode_www_form(to_string(v))}" end)
    |> Enum.join("&")
  end
end
