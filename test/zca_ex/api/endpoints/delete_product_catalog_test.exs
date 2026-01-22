defmodule ZcaEx.Api.Endpoints.DeleteProductCatalogTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.DeleteProductCatalog
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
    test "builds correct params with single product_id as list" do
      params = DeleteProductCatalog.build_params("cat1", ["prod1"])

      assert params.catalog_id == "cat1"
      assert params.product_ids == ["prod1"]
    end

    test "builds correct params with multiple product_ids" do
      params = DeleteProductCatalog.build_params("cat1", ["prod1", "prod2", "prod3"])

      assert params.catalog_id == "cat1"
      assert params.product_ids == ["prod1", "prod2", "prod3"]
    end
  end

  describe "build_url/2" do
    test "builds correct URL", %{session: session} do
      url = DeleteProductCatalog.build_url("https://catalog.zalo.me", session)

      assert url =~ "https://catalog.zalo.me/api/prodcatalog/product/mdelete"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "delete/4 validation with single product_id" do
    test "returns error for empty catalog_id", %{session: session, credentials: credentials} do
      result = DeleteProductCatalog.delete("", "prod1", session, credentials)

      assert {:error, error} = result
      assert error.message == "catalog_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil catalog_id", %{session: session, credentials: credentials} do
      result = DeleteProductCatalog.delete(nil, "prod1", session, credentials)

      assert {:error, error} = result
      assert error.message == "catalog_id must be a non-empty string"
    end

    test "returns error for empty product_id string", %{
      session: session,
      credentials: credentials
    } do
      result = DeleteProductCatalog.delete("cat1", "", session, credentials)

      assert {:error, error} = result

      assert error.message ==
               "product_ids must be a non-empty string or non-empty list of strings"

      assert error.code == :invalid_input
    end

    test "returns error for nil product_ids", %{session: session, credentials: credentials} do
      result = DeleteProductCatalog.delete("cat1", nil, session, credentials)

      assert {:error, error} = result

      assert error.message ==
               "product_ids must be a non-empty string or non-empty list of strings"
    end

    test "normalizes single string product_id to list", %{
      session: session,
      credentials: credentials
    } do
      session_no_service = %{session | zpw_service_map: %{}}
      result = DeleteProductCatalog.delete("cat1", "prod1", session_no_service, credentials)

      assert {:error, error} = result
      assert error.code == :service_not_found
    end
  end

  describe "delete/4 validation with list of product_ids" do
    test "returns error for empty list", %{session: session, credentials: credentials} do
      result = DeleteProductCatalog.delete("cat1", [], session, credentials)

      assert {:error, error} = result
      assert error.message == "product_ids must not be empty"
      assert error.code == :invalid_input
    end

    test "returns error for list with empty string", %{session: session, credentials: credentials} do
      result = DeleteProductCatalog.delete("cat1", ["prod1", ""], session, credentials)

      assert {:error, error} = result
      assert error.message == "all product_ids must be non-empty strings"
      assert error.code == :invalid_input
    end

    test "returns error for list with nil", %{session: session, credentials: credentials} do
      result = DeleteProductCatalog.delete("cat1", ["prod1", nil], session, credentials)

      assert {:error, error} = result
      assert error.message == "all product_ids must be non-empty strings"
    end

    test "accepts valid list of product_ids", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      result =
        DeleteProductCatalog.delete("cat1", ["prod1", "prod2"], session_no_service, credentials)

      assert {:error, error} = result
      assert error.code == :service_not_found
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = DeleteProductCatalog.delete("cat1", ["prod1"], session_no_service, credentials)

      assert {:error, error} = result
      assert error.message == "catalog service URL not found"
      assert error.code == :service_not_found
    end
  end
end
