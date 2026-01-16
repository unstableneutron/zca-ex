defmodule ZcaEx.Test.MockAccountClient do
  @moduledoc "Mock HTTP client for testing API endpoints"

  @type response :: %{status: integer(), body: String.t(), headers: [{String.t(), String.t()}]}

  @doc """
  Set up mock response for next HTTP call.
  Call this at the start of your test.
  """
  @spec setup_mock(response()) :: :ok
  def setup_mock(response) do
    Process.put(:mock_http_response, response)
    :ok
  end

  @doc """
  Get the last request made.
  Returns `{url, body, headers}` or nil if no request was made.
  """
  @spec get_last_request() :: {String.t(), String.t(), [{String.t(), String.t()}]} | nil
  def get_last_request do
    Process.get(:mock_last_request)
  end

  @doc "Mock POST request"
  @spec post(term(), String.t(), String.t(), String.t(), [{String.t(), String.t()}]) ::
          {:ok, ZcaEx.HTTP.Response.t()} | {:error, term()}
  def post(_account_id, url, body, _user_agent, headers \\ []) do
    Process.put(:mock_last_request, {url, body, headers})

    case Process.get(:mock_http_response) do
      nil ->
        {:error, :no_mock_response}

      %{status: status, body: response_body, headers: resp_headers} ->
        {:ok, %ZcaEx.HTTP.Response{status: status, body: response_body, headers: resp_headers}}
    end
  end
end
