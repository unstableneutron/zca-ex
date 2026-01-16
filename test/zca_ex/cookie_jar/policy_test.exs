defmodule ZcaEx.CookieJar.PolicyTest do
  use ExUnit.Case, async: true

  alias ZcaEx.CookieJar.{Cookie, Policy}

  describe "domain_matches?/2" do
    test "host-only cookie requires exact match" do
      cookie = %Cookie{name: "test", value: "1", domain: "example.com", host_only: true}

      assert Policy.domain_matches?("example.com", cookie)
      assert Policy.domain_matches?("EXAMPLE.COM", cookie)
      refute Policy.domain_matches?("sub.example.com", cookie)
      refute Policy.domain_matches?("other.com", cookie)
    end

    test "non-host-only cookie matches domain suffix" do
      cookie = %Cookie{name: "test", value: "1", domain: "example.com", host_only: false}

      assert Policy.domain_matches?("example.com", cookie)
      assert Policy.domain_matches?("sub.example.com", cookie)
      assert Policy.domain_matches?("deep.sub.example.com", cookie)
      refute Policy.domain_matches?("notexample.com", cookie)
      refute Policy.domain_matches?("other.com", cookie)
    end

    test "handles leading dot in cookie domain" do
      cookie = %Cookie{name: "test", value: "1", domain: ".example.com", host_only: false}

      assert Policy.domain_matches?("example.com", cookie)
      assert Policy.domain_matches?("sub.example.com", cookie)
    end

    test "case insensitive matching" do
      cookie = %Cookie{name: "test", value: "1", domain: "Example.Com", host_only: false}

      assert Policy.domain_matches?("example.com", cookie)
      assert Policy.domain_matches?("SUB.EXAMPLE.COM", cookie)
    end
  end

  describe "path_matches?/2" do
    test "exact path match" do
      assert Policy.path_matches?("/api", "/api")
      assert Policy.path_matches?("/", "/")
    end

    test "path prefix with trailing slash" do
      assert Policy.path_matches?("/api/v1", "/api/")
      assert Policy.path_matches?("/api/v1/users", "/api/")
    end

    test "path prefix without trailing slash requires slash after" do
      assert Policy.path_matches?("/api/v1", "/api")
      assert Policy.path_matches?("/api/v1/users", "/api")
      refute Policy.path_matches?("/api-v2", "/api")
      refute Policy.path_matches?("/apiv1", "/api")
    end

    test "root path matches everything" do
      assert Policy.path_matches?("/", "/")
      assert Policy.path_matches?("/any", "/")
      assert Policy.path_matches?("/any/path", "/")
    end

    test "handles nil path" do
      assert Policy.path_matches?(nil, "/")
      assert Policy.path_matches?("/test", nil)
    end
  end

  describe "default_path/1" do
    test "empty or nil returns root" do
      assert Policy.default_path(nil) == "/"
      assert Policy.default_path("") == "/"
    end

    test "path without leading slash returns root" do
      assert Policy.default_path("api/v1") == "/"
    end

    test "single slash returns root" do
      assert Policy.default_path("/") == "/"
    end

    test "path with file returns directory" do
      assert Policy.default_path("/api/v1/users") == "/api/v1"
      assert Policy.default_path("/path/to/resource") == "/path/to"
    end

    test "path with single component returns root" do
      assert Policy.default_path("/api") == "/"
    end
  end

  describe "public_suffix?/1" do
    test "zalo domains are not public suffixes" do
      refute Policy.public_suffix?("zalo.me")
      refute Policy.public_suffix?("zaloapp.com")
      refute Policy.public_suffix?("chat.zalo.me")
      refute Policy.public_suffix?("sub.zalo.me")
      refute Policy.public_suffix?("api.chat.zalo.me")
    end

    test "TLD-only is public suffix" do
      assert Policy.public_suffix?("com")
      assert Policy.public_suffix?("org")
      assert Policy.public_suffix?("net")
    end

    test "regular domains are not public suffixes" do
      refute Policy.public_suffix?("example.com")
      refute Policy.public_suffix?("test.org")
    end
  end

  describe "normalize_domain/1" do
    test "lowercases domain" do
      assert Policy.normalize_domain("EXAMPLE.COM") == "example.com"
      assert Policy.normalize_domain("Example.Com") == "example.com"
    end

    test "removes leading dot" do
      assert Policy.normalize_domain(".example.com") == "example.com"
    end

    test "handles nil" do
      assert Policy.normalize_domain(nil) == ""
    end
  end

  describe "valid_domain_for_request?/2" do
    test "exact match is valid" do
      assert Policy.valid_domain_for_request?("example.com", "example.com")
      assert Policy.valid_domain_for_request?("EXAMPLE.COM", "example.com")
    end

    test "parent domain is valid" do
      assert Policy.valid_domain_for_request?("sub.example.com", "example.com")
      assert Policy.valid_domain_for_request?("deep.sub.example.com", "example.com")
    end

    test "unrelated domain is invalid" do
      refute Policy.valid_domain_for_request?("example.com", "other.com")
      refute Policy.valid_domain_for_request?("notexample.com", "example.com")
    end

    test "zalo domains are valid" do
      assert Policy.valid_domain_for_request?("chat.zalo.me", "zalo.me")
      assert Policy.valid_domain_for_request?("api.zaloapp.com", "zaloapp.com")
    end
  end
end
