defmodule ZcaEx.HTTP.AccountClient do
  @moduledoc "HTTP client with automatic cookie handling for accounts"

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

  defp build_form_body(params) do
    params
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} ->
      "#{URI.encode_www_form(to_string(k))}=#{URI.encode_www_form(to_string(v))}"
    end)
    |> Enum.join("&")
  end
end
