defmodule ZcaEx.HTTP.HeaderBuilderTest do
  use ExUnit.Case, async: true

  alias ZcaEx.HTTP.HeaderBuilder

  describe "build/1" do
    test "includes user-agent as first header" do
      headers = HeaderBuilder.build("TestAgent/1.0")

      assert [{"user-agent", "TestAgent/1.0"} | _] = headers
    end

    test "includes default headers" do
      headers = HeaderBuilder.build("TestAgent/1.0")

      assert {"accept", "application/json, text/plain, */*"} in headers
      assert {"origin", "https://chat.zalo.me"} in headers
      assert {"referer", "https://chat.zalo.me/"} in headers
    end
  end

  describe "with_cookie/2" do
    test "prepends cookie header" do
      headers = HeaderBuilder.build("TestAgent/1.0")
      headers_with_cookie = HeaderBuilder.with_cookie(headers, "session=abc123")

      assert [{"cookie", "session=abc123"} | _] = headers_with_cookie
    end
  end
end
