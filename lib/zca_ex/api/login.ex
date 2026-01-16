defmodule ZcaEx.Api.Login do
  @moduledoc "Login API for Zalo authentication"

  alias ZcaEx.Error

  @doc """
  Parse HTTP response and check for Zalo error codes.
  Returns {:ok, response} on success or {:error, ZcaEx.Error.t()} on failure.
  """
  @spec parse_response({:ok, map()} | {:error, term()}) ::
          {:ok, map()} | {:error, Error.t()}
  def parse_response({:ok, %{status: 200, body: body}}) do
    case Jason.decode(body) do
      {:ok, response} ->
        check_error_response(response)

      {:error, _} ->
        {:error, %Error{message: "Failed to decode JSON response", code: nil}}
    end
  end

  def parse_response({:ok, %{status: status}}) do
    {:error, %Error{message: "HTTP request failed", code: status}}
  end

  def parse_response({:error, reason}) do
    {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
  end

  @doc """
  Check for Zalo error codes in both outer and inner (decrypted) responses.
  """
  @spec check_error_response(map()) :: {:ok, map()} | {:error, Error.t()}
  def check_error_response(%{"error_code" => code, "error_message" => message})
      when code != 0 do
    {:error, %Error{message: message, code: code}}
  end

  def check_error_response(%{"error_code" => code} = response) when code != 0 do
    message = Map.get(response, "error_message", "Unknown error")
    {:error, %Error{message: message, code: code}}
  end

  def check_error_response(response), do: {:ok, response}

  @doc """
  Check error in decrypted inner response data.
  Use this after decrypting the inner response from a successful outer response.
  """
  @spec check_inner_response(map()) :: {:ok, map()} | {:error, Error.t()}
  def check_inner_response(data), do: check_error_response(data)
end
