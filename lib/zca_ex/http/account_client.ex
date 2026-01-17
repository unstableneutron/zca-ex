defmodule ZcaEx.HTTP.AccountClient do
  @moduledoc "HTTP client with automatic cookie handling for accounts"
  @behaviour ZcaEx.HTTP.AccountClientBehaviour

  alias ZcaEx.HTTP.{Client, HeaderBuilder, Response}
  alias ZcaEx.HTTP.Middleware.Cookies

  @type result :: {:ok, Response.t()} | {:error, term()}

  @doc "Make a GET request with automatic cookie handling"
  @spec get(term(), String.t(), String.t(), [{String.t(), String.t()}]) :: result()
  def get(account_id, url, user_agent, extra_headers \\ []) do
    headers = HeaderBuilder.build(user_agent) ++ extra_headers
    headers = Cookies.inject(account_id, headers, url)

    case Client.get(url, headers) do
      {:ok, %Response{} = resp} ->
        Cookies.extract_and_store(account_id, resp.headers, url)
        {:ok, resp}

      error ->
        error
    end
  end

  @doc "Make a POST request with automatic cookie handling"
  @spec post(term(), String.t(), binary(), String.t(), [{String.t(), String.t()}]) :: result()
  def post(account_id, url, body, user_agent, extra_headers \\ []) do
    headers = HeaderBuilder.build(user_agent) ++ extra_headers
    headers = Cookies.inject(account_id, headers, url)
    headers = [{"content-type", "application/x-www-form-urlencoded"} | headers]

    case Client.post(url, body, headers) do
      {:ok, %Response{} = resp} ->
        Cookies.extract_and_store(account_id, resp.headers, url)
        {:ok, resp}

      error ->
        error
    end
  end

  @doc """
  Make a POST request with form-encoded body from a params map.
  Automatically builds x-www-form-urlencoded body from params.
  """
  @spec post_form(term(), String.t(), map() | keyword(), String.t(), [{String.t(), String.t()}]) ::
          result()
  def post_form(account_id, url, params, user_agent, extra_headers \\ []) do
    body = build_form_body(params)
    post(account_id, url, body, user_agent, extra_headers)
  end

  @doc """
  Make a POST request with multipart form data.
  Used for file uploads.

  ## Parts format
  Each part is a tuple: `{name, content, opts}` where:
  - `name` - the form field name
  - `content` - binary content
  - `opts` - keyword list with `:filename` and optionally `:content_type`

  ## Example
      parts = [{"chunkContent", binary_data, filename: "file.jpg", content_type: "application/octet-stream"}]
      post_multipart(account_id, url, parts, user_agent)
  """
  @spec post_multipart(
          term(),
          String.t(),
          [{String.t(), binary(), keyword()}],
          String.t(),
          [{String.t(), String.t()}]
        ) :: result()
  def post_multipart(account_id, url, parts, user_agent, extra_headers \\ []) do
    boundary = generate_boundary()
    body = build_multipart_body(parts, boundary)

    headers = HeaderBuilder.build(user_agent) ++ extra_headers
    headers = Cookies.inject(account_id, headers, url)
    headers = [{"content-type", "multipart/form-data; boundary=#{boundary}"} | headers]

    case Client.post(url, body, headers) do
      {:ok, %Response{} = resp} ->
        Cookies.extract_and_store(account_id, resp.headers, url)
        {:ok, resp}

      error ->
        error
    end
  end

  defp build_form_body(params) do
    params
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} ->
      "#{URI.encode_www_form(to_string(k))}=#{URI.encode_www_form(to_string(v))}"
    end)
    |> Enum.join("&")
  end

  defp generate_boundary do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp build_multipart_body(parts, boundary) do
    parts_binary =
      Enum.map(parts, fn {name, content, opts} ->
        filename = Keyword.get(opts, :filename, "file") |> sanitize_filename()
        content_type = Keyword.get(opts, :content_type, "application/octet-stream")

        [
          "--#{boundary}\r\n",
          "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{filename}\"\r\n",
          "Content-Type: #{content_type}\r\n",
          "\r\n",
          content,
          "\r\n"
        ]
      end)

    IO.iodata_to_binary([parts_binary, "--#{boundary}--\r\n"])
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace("\"", "\\\"")
    |> String.replace(~r/[\r\n]/, "")
  end
end
