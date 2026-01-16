defmodule ZcaEx.HTTP.Middleware.Cookies do
  @moduledoc "Cookie middleware for HTTP requests"

  alias ZcaEx.CookieJar
  alias ZcaEx.HTTP.HeaderBuilder

  @doc "Inject cookies into request headers"
  @spec inject(term(), [{String.t(), String.t()}], String.t()) :: [{String.t(), String.t()}]
  def inject(account_id, headers, url) do
    uri = URI.parse(url)
    cookie_string = CookieJar.get_cookie_string(account_id, uri)

    if cookie_string != "" do
      HeaderBuilder.with_cookie(headers, cookie_string)
    else
      headers
    end
  end

  @doc "Extract and store cookies from response headers"
  @spec extract_and_store(term(), [{String.t(), String.t()}], String.t()) :: :ok
  def extract_and_store(account_id, headers, url) do
    uri = URI.parse(url)

    headers
    |> Enum.filter(fn {name, _} -> String.downcase(name) == "set-cookie" end)
    |> Enum.each(fn {_, value} -> CookieJar.store(account_id, uri, value) end)

    :ok
  end
end
