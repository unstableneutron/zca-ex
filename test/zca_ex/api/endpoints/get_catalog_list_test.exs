defmodule ZcaEx.Api.Endpoints.GetCatalogListTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetCatalogList
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

  describe "build_params/3" do
    test "builds correct params with defaults" do
      params = GetCatalogList.build_params(20, -1, 0)

      assert params.version_list_catalog == 0
      assert params.limit == 20
      assert params.last_product_id == -1
      assert params.page == 0
    end

    test "builds correct params with custom values" do
      params = GetCatalogList.build_params(50, 100, 2)

      assert params.version_list_catalog == 0
      assert params.limit == 50
      assert params.last_product_id == 100
      assert params.page == 2
    end
  end

  describe "build_url/2" do
    test "builds correct URL", %{session: session} do
      url = GetCatalogList.build_url("https://catalog.zalo.me", session)

      assert url =~ "https://catalog.zalo.me/api/prodcatalog/catalog/list"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "list/3 validation" do
    test "returns error for zero limit", %{session: session, credentials: credentials} do
      result = GetCatalogList.list(session, credentials, limit: 0)

      assert {:error, error} = result
      assert error.message == "limit must be a positive integer"
      assert error.code == :invalid_input
    end

    test "returns error for negative limit", %{session: session, credentials: credentials} do
      result = GetCatalogList.list(session, credentials, limit: -1)

      assert {:error, error} = result
      assert error.message == "limit must be a positive integer"
      assert error.code == :invalid_input
    end

    test "returns error for non-integer limit", %{session: session, credentials: credentials} do
      result = GetCatalogList.list(session, credentials, limit: "20")

      assert {:error, error} = result
      assert error.message == "limit must be a positive integer"
      assert error.code == :invalid_input
    end

    test "returns error for negative page", %{session: session, credentials: credentials} do
      result = GetCatalogList.list(session, credentials, page: -1)

      assert {:error, error} = result
      assert error.message == "page must be a non-negative integer"
      assert error.code == :invalid_input
    end

    test "returns error for non-integer page", %{session: session, credentials: credentials} do
      result = GetCatalogList.list(session, credentials, page: "0")

      assert {:error, error} = result
      assert error.message == "page must be a non-negative integer"
      assert error.code == :invalid_input
    end

    test "returns error for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = GetCatalogList.list(session_no_service, credentials)

      assert {:error, error} = result
      assert error.message =~ "catalog service URL not found"
      assert error.code == :service_not_found
    end

    test "accepts valid options", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      result = GetCatalogList.list(session_no_service, credentials, limit: 50, page: 2, last_product_id: 100)

      assert {:error, error} = result
      assert error.code == :service_not_found
    end
  end
end
