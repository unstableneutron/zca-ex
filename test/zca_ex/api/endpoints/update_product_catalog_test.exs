defmodule ZcaEx.Api.Endpoints.UpdateProductCatalogTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateProductCatalog
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

  describe "build_params/7" do
    test "builds correct params with photos" do
      params =
        UpdateProductCatalog.build_params(
          "cat1",
          "prod1",
          "Product",
          "100000",
          "Desc",
          1_700_000_000_000,
          ["url1", "url2"]
        )

      assert params.catalog_id == "cat1"
      assert params.product_id == "prod1"
      assert params.product_name == "Product"
      assert params.price == "100000"
      assert params.description == "Desc"
      assert params.create_time == 1_700_000_000_000
      assert params.product_photos == ["url1", "url2"]
      assert params.currency_unit == "₫"
    end

    test "builds correct params without photos" do
      params =
        UpdateProductCatalog.build_params(
          "cat1",
          "prod1",
          "Product",
          "50000",
          "Description",
          1_700_000_000_000,
          []
        )

      assert params.product_photos == []
      assert params.currency_unit == "₫"
    end
  end

  describe "build_url/2" do
    test "builds correct URL", %{session: session} do
      url = UpdateProductCatalog.build_url("https://catalog.zalo.me", session)

      assert url =~ "https://catalog.zalo.me/api/prodcatalog/product/update"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "update/8 validation" do
    test "returns error for empty catalog_id", %{session: session, credentials: credentials} do
      result =
        UpdateProductCatalog.update(
          "",
          "prod1",
          "Product",
          "100",
          "Desc",
          1_700_000_000_000,
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "catalog_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for empty product_id", %{session: session, credentials: credentials} do
      result =
        UpdateProductCatalog.update(
          "cat1",
          "",
          "Product",
          "100",
          "Desc",
          1_700_000_000_000,
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "product_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil product_id", %{session: session, credentials: credentials} do
      result =
        UpdateProductCatalog.update(
          "cat1",
          nil,
          "Product",
          "100",
          "Desc",
          1_700_000_000_000,
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "product_id must be a non-empty string"
    end

    test "returns error for empty product_name", %{session: session, credentials: credentials} do
      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "",
          "100",
          "Desc",
          1_700_000_000_000,
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "product_name must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for empty price", %{session: session, credentials: credentials} do
      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "Product",
          "",
          "Desc",
          1_700_000_000_000,
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "price must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for empty description", %{session: session, credentials: credentials} do
      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "Product",
          "100",
          "",
          1_700_000_000_000,
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "description must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for zero create_time", %{session: session, credentials: credentials} do
      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "Product",
          "100",
          "Desc",
          0,
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "create_time must be a positive integer"
      assert error.code == :invalid_input
    end

    test "returns error for negative create_time", %{session: session, credentials: credentials} do
      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "Product",
          "100",
          "Desc",
          -1,
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "create_time must be a positive integer"
    end

    test "returns error for non-integer create_time", %{
      session: session,
      credentials: credentials
    } do
      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "Product",
          "100",
          "Desc",
          "1700000000000",
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "create_time must be a positive integer"
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "Product",
          "100",
          "Desc",
          1_700_000_000_000,
          session_no_service,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "catalog service URL not found"
      assert error.code == :service_not_found
    end
  end

  describe "update/9 validation" do
    test "returns error for non-list product_photos", %{
      session: session,
      credentials: credentials
    } do
      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "Product",
          "100",
          "Desc",
          1_700_000_000_000,
          "not-a-list",
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "product_photos must be a list"
      assert error.code == :invalid_input
    end

    test "returns error for too many photos", %{session: session, credentials: credentials} do
      photos = ["url1", "url2", "url3", "url4", "url5", "url6"]

      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "Product",
          "100",
          "Desc",
          1_700_000_000_000,
          photos,
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "product_photos must have at most 5 items"
      assert error.code == :invalid_input
    end

    test "accepts exactly 5 photos", %{session: session, credentials: credentials} do
      photos = ["url1", "url2", "url3", "url4", "url5"]
      session_no_service = %{session | zpw_service_map: %{}}

      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "Product",
          "100",
          "Desc",
          1_700_000_000_000,
          photos,
          session_no_service,
          credentials
        )

      assert {:error, error} = result
      assert error.code == :service_not_found
    end

    test "returns error for non-string items in product_photos", %{
      session: session,
      credentials: credentials
    } do
      photos = ["url1", 123, "url3"]

      result =
        UpdateProductCatalog.update(
          "cat1",
          "prod1",
          "Product",
          "100",
          "Desc",
          1_700_000_000_000,
          photos,
          session,
          credentials
        )

      assert {:error, error} = result
      assert error.message == "product_photos must contain only strings"
      assert error.code == :invalid_input
    end
  end
end
