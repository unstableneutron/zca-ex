defmodule ZcaEx.Api.Endpoints.GetProductCatalogListTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetProductCatalogList
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "catalog" => ["https://catalog.zalo.me"]
      },
      api_type: 30,
      api_version: 645
    }

    {:ok, credentials} =
      Credentials.new(
        imei: "test-imei-12345",
        user_agent: "Mozilla/5.0 Test",
        cookies: [%{"name" => "test", "value" => "cookie"}],
        language: "vi"
      )

    {:ok, session: session, credentials: credentials}
  end

  describe "build_params/2" do
    test "builds correct params with defaults" do
      params = GetProductCatalogList.build_params("cat1", [])

      assert params.catalog_id == "cat1"
      assert params.limit == 100
      assert params.version_catalog == 0
      assert params.last_product_id == -1
      assert params.page == 0
    end

    test "builds correct params with custom options" do
      opts = [limit: 50, version_catalog: 5, last_product_id: 123, page: 2]
      params = GetProductCatalogList.build_params("cat1", opts)

      assert params.catalog_id == "cat1"
      assert params.limit == 50
      assert params.version_catalog == 5
      assert params.last_product_id == 123
      assert params.page == 2
    end

    test "builds correct params with partial options" do
      opts = [limit: 25]
      params = GetProductCatalogList.build_params("cat1", opts)

      assert params.limit == 25
      assert params.version_catalog == 0
      assert params.last_product_id == -1
      assert params.page == 0
    end
  end

  describe "build_url/2" do
    test "builds correct URL", %{session: session} do
      url = GetProductCatalogList.build_url("https://catalog.zalo.me", session)

      assert url =~ "https://catalog.zalo.me/api/prodcatalog/product/list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "list/3 validation" do
    test "returns error for empty catalog_id", %{session: session, credentials: credentials} do
      result = GetProductCatalogList.list("", session, credentials)

      assert {:error, error} = result
      assert error.message == "catalog_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil catalog_id", %{session: session, credentials: credentials} do
      result = GetProductCatalogList.list(nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "catalog_id must be a non-empty string"
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = GetProductCatalogList.list("cat1", session_no_service, credentials)

      assert {:error, error} = result
      assert error.message == "catalog service URL not found"
      assert error.code == :service_not_found
    end
  end

  describe "list/4 validation" do
    test "returns error for empty catalog_id with opts", %{session: session, credentials: credentials} do
      result = GetProductCatalogList.list("", [limit: 50], session, credentials)

      assert {:error, error} = result
      assert error.message == "catalog_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL with opts", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = GetProductCatalogList.list("cat1", [limit: 50], session_no_service, credentials)

      assert {:error, error} = result
      assert error.message == "catalog service URL not found"
      assert error.code == :service_not_found
    end
  end
end
