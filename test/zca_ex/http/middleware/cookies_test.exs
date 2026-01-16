defmodule ZcaEx.HTTP.Middleware.CookiesTest do
  use ExUnit.Case, async: false

  alias ZcaEx.HTTP.Middleware.Cookies
  alias ZcaEx.CookieJar

  setup do
    account_id = make_ref()
    start_supervised!({CookieJar, account_id: account_id})
    {:ok, account_id: account_id}
  end

  describe "inject/3" do
    test "injects cookies into headers", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      CookieJar.store(account_id, uri, "session=abc")

      headers = [{"accept", "application/json"}]
      result = Cookies.inject(account_id, headers, "https://example.com/api")

      assert {"cookie", "session=abc"} in result
    end

    test "returns original headers when no cookies", %{account_id: account_id} do
      headers = [{"accept", "application/json"}]
      result = Cookies.inject(account_id, headers, "https://example.com/api")

      assert result == headers
    end
  end

  describe "extract_and_store/3" do
    test "stores cookies from set-cookie headers", %{account_id: account_id} do
      headers = [
        {"Set-Cookie", "token=xyz; Path=/"},
        {"content-type", "application/json"}
      ]

      Cookies.extract_and_store(account_id, headers, "https://example.com/")

      result = CookieJar.get_cookie_string(account_id, "https://example.com/")
      assert result == "token=xyz"
    end
  end
end
