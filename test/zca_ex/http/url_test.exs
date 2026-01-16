defmodule ZcaEx.HTTP.URLTest do
  use ExUnit.Case, async: true

  alias ZcaEx.HTTP.URL

  describe "build/3" do
    test "adds default api version params" do
      url = URL.build("https://api.zalo.me/path")

      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "merges custom params" do
      url = URL.build("https://api.zalo.me/path", %{"foo" => "bar"})

      assert url =~ "foo=bar"
      assert url =~ "zpw_ver=645"
    end

    test "preserves existing query params" do
      url = URL.build("https://api.zalo.me/path?existing=value", %{"new" => "param"})

      assert url =~ "existing=value"
      assert url =~ "new=param"
    end

    test "skips api version when disabled" do
      url = URL.build("https://api.zalo.me/path", %{}, api_version: false)

      refute url =~ "zpw_ver"
      refute url =~ "zpw_type"
    end

    test "allows custom api_type and version" do
      url = URL.build("https://api.zalo.me/path", %{}, api_type: 50, version: 700)

      assert url =~ "zpw_ver=700"
      assert url =~ "zpw_type=50"
    end
  end
end
