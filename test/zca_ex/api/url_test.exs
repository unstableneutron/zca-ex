defmodule ZcaEx.Api.UrlTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Url
  alias ZcaEx.Account.Session

  describe "build/3" do
    test "builds URL with params" do
      result = Url.build("https://api.zalo.me/test", %{"foo" => "bar"})

      assert result =~ "foo=bar"
      assert result =~ "zpw_ver="
      assert result =~ "zpw_type="
    end

    test "adds default api version params" do
      result = Url.build("https://api.zalo.me/test")

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["zpw_ver"] == "645"
      assert params["zpw_type"] == "30"
    end

    test "uses custom api version params" do
      result = Url.build("https://api.zalo.me/test", %{}, api_type: 50, version: 700)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["zpw_ver"] == "700"
      assert params["zpw_type"] == "50"
    end

    test "skips api version when disabled" do
      result = Url.build("https://api.zalo.me/test", %{"a" => "1"}, api_version: false)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      refute Map.has_key?(params, "zpw_ver")
      refute Map.has_key?(params, "zpw_type")
      assert params["a"] == "1"
    end

    test "adds nretry when specified" do
      result = Url.build("https://api.zalo.me/test", %{}, nretry: 2)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["nretry"] == "2"
    end

    test "does not add nretry when 0" do
      result = Url.build("https://api.zalo.me/test", %{}, nretry: 0)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      refute Map.has_key?(params, "nretry")
    end

    test "preserves existing query params in URL" do
      result = Url.build("https://api.zalo.me/test?existing=value", %{"new" => "param"})

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["existing"] == "value"
      assert params["new"] == "param"
    end

    test "handles atom keys in params" do
      result = Url.build("https://api.zalo.me/test", %{foo: "bar"}, api_version: false)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["foo"] == "bar"
    end

    test "converts numeric values to string" do
      result = Url.build("https://api.zalo.me/test", %{"num" => 123}, api_version: false)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["num"] == "123"
    end

    test "new params override existing URL params" do
      result = Url.build("https://api.zalo.me/test?foo=old", %{"foo" => "new"}, api_version: false)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["foo"] == "new"
    end

    test "filters out nil values from params" do
      result = Url.build("https://api.zalo.me/test", %{"keep" => "value", "drop" => nil}, api_version: false)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["keep"] == "value"
      refute Map.has_key?(params, "drop")
    end
  end

  describe "build_for_session/4" do
    test "uses session api_type and api_version" do
      session = %Session{
        uid: "123",
        secret_key: "key",
        zpw_service_map: %{},
        api_type: 40,
        api_version: 700
      }

      result = Url.build_for_session("https://api.zalo.me/test", %{}, session)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["zpw_type"] == "40"
      assert params["zpw_ver"] == "700"
    end

    test "allows overriding session values" do
      session = %Session{
        uid: "123",
        secret_key: "key",
        zpw_service_map: %{},
        api_type: 40,
        api_version: 700
      }

      result =
        Url.build_for_session("https://api.zalo.me/test", %{}, session, api_type: 99)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["zpw_type"] == "99"
      assert params["zpw_ver"] == "700"
    end
  end

  describe "with_retry/2" do
    test "appends nretry to existing URL" do
      url = "https://api.zalo.me/test?foo=bar"

      result = Url.with_retry(url, 3)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["nretry"] == "3"
      assert params["foo"] == "bar"
    end

    test "returns original URL when retry is 0" do
      url = "https://api.zalo.me/test?foo=bar"

      result = Url.with_retry(url, 0)

      assert result == url
    end

    test "handles URL without existing params" do
      url = "https://api.zalo.me/test"

      result = Url.with_retry(url, 1)

      uri = URI.parse(result)
      params = URI.decode_query(uri.query)

      assert params["nretry"] == "1"
    end
  end
end
