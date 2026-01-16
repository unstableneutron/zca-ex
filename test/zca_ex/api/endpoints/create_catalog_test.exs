defmodule ZcaEx.Api.Endpoints.CreateCatalogTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.CreateCatalog
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

  describe "build_params/1" do
    test "builds correct params" do
      params = CreateCatalog.build_params("My Catalog")

      assert params.catalog_name == "My Catalog"
      assert params.catalog_photo == ""
    end
  end

  describe "build_url/2" do
    test "builds correct URL", %{session: session} do
      url = CreateCatalog.build_url("https://catalog.zalo.me", session)

      assert url =~ "https://catalog.zalo.me/api/prodcatalog/catalog/create"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "create/3 validation" do
    test "returns error for empty catalog_name", %{session: session, credentials: credentials} do
      result = CreateCatalog.create("", session, credentials)

      assert {:error, error} = result
      assert error.message == "catalog_name must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil catalog_name", %{session: session, credentials: credentials} do
      result = CreateCatalog.create(nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "catalog_name must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for non-string catalog_name", %{session: session, credentials: credentials} do
      result = CreateCatalog.create(123, session, credentials)

      assert {:error, error} = result
      assert error.message == "catalog_name must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = CreateCatalog.create("My Catalog", session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "catalog service URL not found"
      assert error.code == :service_not_found
    end
  end
end
