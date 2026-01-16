defmodule ZcaEx.Api.Response do
  @moduledoc "Utilities for handling Zalo API responses"

  alias ZcaEx.Error
  alias ZcaEx.Crypto.AesCbc
  alias ZcaEx.HTTP.Response, as: HTTPResponse

  @type t :: {:ok, map()} | {:error, Error.t()}

  @doc """
  Parse and decrypt API response.
  Handles both outer and inner error codes.
  """
  @spec parse(HTTPResponse.t() | {:ok, HTTPResponse.t()} | {:error, term()}, String.t()) :: t()
  def parse({:ok, %HTTPResponse{} = resp}, secret_key), do: parse(resp, secret_key)

  def parse({:error, reason}, _secret_key) do
    {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
  end

  def parse(%HTTPResponse{status: status}, _secret_key) when status != 200 do
    {:error, %Error{message: "HTTP request failed", code: status}}
  end

  def parse(%HTTPResponse{status: 200, body: body}, secret_key) do
    with {:ok, json} <- decode_json(body),
         :ok <- check_error(json),
         {:ok, data} <- decrypt_data(json, secret_key),
         :ok <- check_inner_error(data) do
      {:ok, extract_data(data)}
    end
  end

  @doc """
  Parse response without decryption (for unencrypted API responses).
  """
  @spec parse_unencrypted(HTTPResponse.t() | {:ok, HTTPResponse.t()} | {:error, term()}) :: t()
  def parse_unencrypted({:ok, %HTTPResponse{} = resp}), do: parse_unencrypted(resp)

  def parse_unencrypted({:error, reason}) do
    {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
  end

  def parse_unencrypted(%HTTPResponse{status: status}) when status != 200 do
    {:error, %Error{message: "HTTP request failed", code: status}}
  end

  def parse_unencrypted(%HTTPResponse{status: 200, body: body}) do
    with {:ok, json} <- decode_json(body),
         :ok <- check_error(json) do
      {:ok, extract_data(json)}
    end
  end

  @doc "Check for error code in response"
  @spec check_error(map()) :: :ok | {:error, Error.t()}
  def check_error(%{"error_code" => code, "error_message" => message}) when code != 0 do
    {:error, %Error{message: message, code: code}}
  end

  def check_error(%{"error_code" => code} = resp) when code != 0 do
    message = Map.get(resp, "error_message", "Unknown error")
    {:error, %Error{message: message, code: code}}
  end

  def check_error(_), do: :ok

  @doc "Decrypt the data field in response using base64-encoded key"
  @spec decrypt_data(map(), String.t()) :: {:ok, map() | String.t()} | {:error, Error.t()}
  def decrypt_data(%{"data" => data}, secret_key) when is_binary(data) do
    case AesCbc.decrypt_base64_key(secret_key, data) do
      {:error, reason} ->
        {:error, %Error{message: "Decryption failed: #{inspect(reason)}", code: nil}}

      decrypted when is_binary(decrypted) ->
        case Jason.decode(decrypted) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:ok, decrypted}
        end
    end
  end

  def decrypt_data(%{"data" => data}, _secret_key) when is_map(data) do
    {:ok, data}
  end

  def decrypt_data(response, _secret_key) do
    {:ok, response}
  end

  @doc "Decrypt response data using UTF-8 key (32 chars)"
  @spec decrypt_data_utf8(map(), String.t(), :hex | :base64) ::
          {:ok, map() | String.t()} | {:error, Error.t()}
  def decrypt_data_utf8(%{"data" => data}, key, input_format) when is_binary(data) do
    case AesCbc.decrypt_utf8_key(key, data, input_format) do
      nil ->
        {:error, %Error{message: "Decryption failed", code: nil}}

      decrypted ->
        case Jason.decode(decrypted) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:ok, decrypted}
        end
    end
  end

  def decrypt_data_utf8(%{"data" => data}, _key, _format) when is_map(data) do
    {:ok, data}
  end

  def decrypt_data_utf8(response, _key, _format) do
    {:ok, response}
  end

  defp decode_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, json} -> {:ok, json}
      {:error, _} -> {:error, %Error{message: "Failed to decode JSON response", code: nil}}
    end
  end

  defp check_inner_error(%{"error_code" => code, "error_message" => message}) when code != 0 do
    {:error, %Error{message: message, code: code}}
  end

  defp check_inner_error(%{"error_code" => code} = resp) when code != 0 do
    message = Map.get(resp, "error_message", "Unknown error")
    {:error, %Error{message: message, code: code}}
  end

  defp check_inner_error(_), do: :ok

  defp extract_data(%{"data" => data}), do: data
  defp extract_data(data), do: data
end
