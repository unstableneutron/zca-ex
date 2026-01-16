defmodule ZcaEx.CookieJar.JarTest do
  use ExUnit.Case, async: false

  alias ZcaEx.CookieJar

  setup do
    # Use unique account_id to avoid conflicts between tests
    account_id = System.unique_integer([:positive, :monotonic])
    # Start the CookieJar for this test - Registry is already started by Application
    {:ok, _pid} = CookieJar.start_link(account_id: account_id)
    on_exit(fn -> 
      try do
        GenServer.stop({:via, Registry, {ZcaEx.Registry, {:cookie_jar, account_id}}})
      catch
        :exit, _ -> :ok
      end
    end)
    {:ok, account_id: account_id}
  end

  describe "store and retrieve cookies" do
    test "stores and retrieves a simple cookie", %{account_id: account_id} do
      uri = URI.parse("https://example.com/path")
      :ok = CookieJar.store(account_id, uri, "session=abc123")

      assert CookieJar.get_cookie_string(account_id, uri) == "session=abc123"
    end

    test "stores multiple cookies", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "a=1")
      :ok = CookieJar.store(account_id, uri, "b=2")

      result = CookieJar.get_cookie_string(account_id, uri)
      assert result =~ "a=1"
      assert result =~ "b=2"
    end

    test "accepts URI string", %{account_id: account_id} do
      :ok = CookieJar.store(account_id, "https://example.com/", "test=value")
      assert CookieJar.get_cookie_string(account_id, "https://example.com/") == "test=value"
    end
  end

  describe "cookie expiration" do
    test "excludes expired cookies", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "expired=yes; Max-Age=0")
      :ok = CookieJar.store(account_id, uri, "valid=yes")

      assert CookieJar.get_cookie_string(account_id, uri) == "valid=yes"
    end

    test "includes non-expired cookies", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "future=yes; Max-Age=3600")

      assert CookieJar.get_cookie_string(account_id, uri) == "future=yes"
    end
  end

  describe "domain matching" do
    test "exact domain match for host-only cookies", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "host=only")

      assert CookieJar.get_cookie_string(account_id, "https://example.com/") == "host=only"
      assert CookieJar.get_cookie_string(account_id, "https://sub.example.com/") == ""
    end

    test "suffix domain match for domain cookies", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "shared=yes; Domain=example.com")

      assert CookieJar.get_cookie_string(account_id, "https://example.com/") == "shared=yes"
      assert CookieJar.get_cookie_string(account_id, "https://sub.example.com/") == "shared=yes"
      assert CookieJar.get_cookie_string(account_id, "https://other.com/") == ""
    end

    test "strips leading dot from domain", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "dotted=yes; Domain=.example.com")

      assert CookieJar.get_cookie_string(account_id, "https://sub.example.com/") == "dotted=yes"
    end
  end

  describe "path matching" do
    test "matches exact path", %{account_id: account_id} do
      uri = URI.parse("https://example.com/api")
      :ok = CookieJar.store(account_id, uri, "api=token; Path=/api")

      assert CookieJar.get_cookie_string(account_id, "https://example.com/api") == "api=token"
      assert CookieJar.get_cookie_string(account_id, "https://example.com/api/v1") == "api=token"
      assert CookieJar.get_cookie_string(account_id, "https://example.com/other") == ""
    end

    test "root path matches all", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "root=yes; Path=/")

      assert CookieJar.get_cookie_string(account_id, "https://example.com/any/path") == "root=yes"
    end
  end

  describe "secure cookies" do
    test "secure cookie only sent over HTTPS", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "secure=yes; Secure")
      :ok = CookieJar.store(account_id, uri, "normal=yes")

      https_cookies = CookieJar.get_cookie_string(account_id, "https://example.com/")
      assert https_cookies =~ "secure=yes"
      assert https_cookies =~ "normal=yes"

      http_cookies = CookieJar.get_cookie_string(account_id, "http://example.com/")
      refute http_cookies =~ "secure=yes"
      assert http_cookies =~ "normal=yes"
    end
  end

  describe "export and import" do
    test "round-trip export/import", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "a=1")
      :ok = CookieJar.store(account_id, uri, "b=2; Secure; HttpOnly")

      exported = CookieJar.export(account_id)
      assert length(exported) == 2

      new_account = System.unique_integer([:positive, :monotonic])
      {:ok, _} = CookieJar.start_link(account_id: new_account)
      :ok = CookieJar.import(new_account, exported)

      result = CookieJar.get_cookie_string(new_account, uri)
      assert result =~ "a=1"
      assert result =~ "b=2"
    end

    test "import from Zalo JSON format with cookies wrapper", %{account_id: account_id} do
      zalo_format = %{
        "cookies" => [
          %{
            "name" => "zalo_token",
            "value" => "abc123",
            "domain" => "zalo.me",
            "path" => "/",
            "secure" => true,
            "httpOnly" => true,
            "hostOnly" => false
          }
        ]
      }

      :ok = CookieJar.import(account_id, zalo_format)

      result = CookieJar.get_cookie_string(account_id, "https://zalo.me/")
      assert result == "zalo_token=abc123"
    end

    test "import with atom keys", %{account_id: account_id} do
      cookies = [
        %{
          name: "test",
          value: "value",
          domain: "example.com",
          path: "/",
          secure: false,
          http_only: false,
          host_only: true
        }
      ]

      :ok = CookieJar.import(account_id, cookies)
      assert CookieJar.get_cookie_string(account_id, "https://example.com/") == "test=value"
    end
  end

  describe "initial cookies option" do
    test "starts with pre-loaded cookies" do
      account_id = System.unique_integer([:positive, :monotonic])
      cookies = [
        %{
          "name" => "preloaded",
          "value" => "yes",
          "domain" => "example.com",
          "path" => "/",
          "hostOnly" => true
        }
      ]

      {:ok, _} = CookieJar.start_link(account_id: account_id, cookies: cookies)

      result = CookieJar.get_cookie_string(account_id, "https://example.com/")
      assert result == "preloaded=yes"
    end
  end

  describe "RFC6265 compliance" do
    test "Max-Age takes precedence over Expires", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "test=value; Max-Age=3600; Expires=Thu, 01 Jan 1970 00:00:00 GMT")

      assert CookieJar.get_cookie_string(account_id, uri) == "test=value"
    end

    test "Max-Age=0 deletes cookie", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "tobedeleted=yes")
      assert CookieJar.get_cookie_string(account_id, uri) == "tobedeleted=yes"

      :ok = CookieJar.store(account_id, uri, "tobedeleted=; Max-Age=0")
      assert CookieJar.get_cookie_string(account_id, uri) == ""
    end

    test "parses SameSite attribute", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "strict=val; SameSite=Strict")
      :ok = CookieJar.store(account_id, uri, "lax=val; SameSite=Lax")
      :ok = CookieJar.store(account_id, uri, "none=val; SameSite=None")

      exported = CookieJar.export(account_id)
      strict_cookie = Enum.find(exported, &(&1["name"] == "strict"))
      lax_cookie = Enum.find(exported, &(&1["name"] == "lax"))
      none_cookie = Enum.find(exported, &(&1["name"] == "none"))

      assert strict_cookie["sameSite"] == :strict
      assert lax_cookie["sameSite"] == :lax
      assert none_cookie["sameSite"] == :none
    end

    test "no Domain attribute makes cookie host-only", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "hostonly=yes")

      assert CookieJar.get_cookie_string(account_id, "https://example.com/") == "hostonly=yes"
      assert CookieJar.get_cookie_string(account_id, "https://sub.example.com/") == ""
    end

    test "uses default path when no Path attribute", %{account_id: account_id} do
      uri = URI.parse("https://example.com/api/v1/endpoint")
      :ok = CookieJar.store(account_id, uri, "test=value")

      assert CookieJar.get_cookie_string(account_id, "https://example.com/api/v1/other") == "test=value"
      assert CookieJar.get_cookie_string(account_id, "https://example.com/api/other") == ""
    end

    test "export excludes expired cookies", %{account_id: account_id} do
      uri = URI.parse("https://example.com/")
      :ok = CookieJar.store(account_id, uri, "valid=yes; Max-Age=3600")
      :ok = CookieJar.store(account_id, uri, "expired=yes; Max-Age=0")

      exported = CookieJar.export(account_id)
      names = Enum.map(exported, & &1["name"])

      assert "valid" in names
      refute "expired" in names
    end

    test "import with SameSite attribute", %{account_id: account_id} do
      cookies = [
        %{
          "name" => "test",
          "value" => "value",
          "domain" => "example.com",
          "path" => "/",
          "sameSite" => :strict,
          "hostOnly" => true
        }
      ]

      :ok = CookieJar.import(account_id, cookies)

      exported = CookieJar.export(account_id)
      cookie = Enum.find(exported, &(&1["name"] == "test"))
      assert cookie["sameSite"] == :strict
    end
  end
end
