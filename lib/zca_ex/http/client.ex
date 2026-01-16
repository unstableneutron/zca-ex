defmodule ZcaEx.HTTP.Client do
  @moduledoc "HTTP client using Req"

  alias ZcaEx.HTTP.{Request, Response}

  @type result :: {:ok, Response.t()} | {:error, term()}

  @doc """
  Execute an HTTP request.

  Uses Req with automatic:
  - Compression (gzip/deflate)
  - Redirect following
  - Retry on transient errors
  """
  @spec request(Request.t()) :: result()
  def request(%Request{} = req) do
    opts = [
      method: req.method,
      url: req.url,
      headers: req.headers,
      body: req.body,
      # Disable automatic JSON decoding - we handle it ourselves
      decode_body: false,
      # Keep compressed_body handling to Req
      compressed: true,
      # Retry transient errors
      retry: :transient,
      max_retries: 2
    ]

    case Req.request(opts) do
      {:ok, %Req.Response{status: status, headers: headers, body: body}} ->
        # Convert headers from map to list format for compatibility
        header_list = Enum.flat_map(headers, fn {k, v} -> 
          if is_list(v), do: Enum.map(v, &{k, &1}), else: [{k, v}]
        end)
        {:ok, %Response{status: status, headers: header_list, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get(String.t(), [{String.t(), String.t()}]) :: result()
  def get(url, headers \\ []) do
    request(%Request{method: :get, url: url, headers: headers})
  end

  @spec post(String.t(), binary(), [{String.t(), String.t()}]) :: result()
  def post(url, body, headers \\ []) do
    request(%Request{method: :post, url: url, headers: headers, body: body})
  end

  @doc """
  Create a reusable Req client with Zalo-specific defaults.
  """
  def new(opts \\ []) do
    user_agent = Keyword.get(opts, :user_agent, default_user_agent())
    cookies = Keyword.get(opts, :cookies, "")

    Req.new(
      headers: default_headers(user_agent, cookies),
      decode_body: false,
      compressed: true,
      retry: :transient,
      max_retries: 2
    )
  end

  defp default_headers(user_agent, cookies) do
    headers = [
      {"accept", "application/json, text/plain, */*"},
      {"accept-language", "en-US,en;q=0.9"},
      {"origin", "https://chat.zalo.me"},
      {"referer", "https://chat.zalo.me/"},
      {"sec-ch-ua", "\"Chromium\";v=\"122\", \"Not(A:Brand\";v=\"24\", \"Google Chrome\";v=\"122\""},
      {"sec-ch-ua-mobile", "?0"},
      {"sec-ch-ua-platform", "\"macOS\""},
      {"sec-fetch-dest", "empty"},
      {"sec-fetch-mode", "cors"},
      {"sec-fetch-site", "same-site"},
      {"user-agent", user_agent}
    ]

    if cookies != "" do
      [{"cookie", cookies} | headers]
    else
      headers
    end
  end

  defp default_user_agent do
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
  end

  @doc "Get a header value by name (case-insensitive)"
  @spec get_header([{String.t(), String.t()}], String.t()) :: String.t() | nil
  def get_header(headers, name) do
    name_lower = String.downcase(name)

    Enum.find_value(headers, fn {k, v} ->
      if String.downcase(k) == name_lower, do: v
    end)
  end
end
