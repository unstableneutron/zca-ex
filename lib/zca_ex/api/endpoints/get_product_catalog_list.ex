defmodule ZcaEx.Api.Endpoints.GetProductCatalogList do
  @moduledoc """
  Get product catalog list.

  Note: This API is used for zBusiness accounts.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @default_limit 100
  @default_version_catalog 0
  @default_last_product_id -1
  @default_page 0

  @doc """
  Get product catalog list.

  ## Parameters
    - catalog_id: Catalog ID (required, non-empty string)
    - opts: Optional parameters
      - limit: Number of items to retrieve (default: 100)
      - version_catalog: Version catalog (default: 0)
      - last_product_id: Last product ID for pagination (default: -1)
      - page: Page number (default: 0)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{items: list(), version: integer(), has_more: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec list(String.t(), keyword(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def list(catalog_id, opts \\ [], session, credentials) do
    with :ok <- validate_catalog_id(catalog_id),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(catalog_id, opts)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, data} -> {:ok, transform_response(data)}
                {:error, _} = error -> error
              end

            {:error, reason} ->
              {:error, Error.new(:network, "Request failed: #{inspect(reason)}", reason: reason)}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  defp validate_catalog_id(catalog_id) when is_binary(catalog_id) and byte_size(catalog_id) > 0, do: :ok
  defp validate_catalog_id(_), do: {:error, Error.new(:api, "catalog_id must be a non-empty string", code: :invalid_input)}

  @doc false
  def build_params(catalog_id, opts) do
    %{
      catalog_id: catalog_id,
      limit: Keyword.get(opts, :limit, @default_limit),
      version_catalog: Keyword.get(opts, :version_catalog, @default_version_catalog),
      last_product_id: Keyword.get(opts, :last_product_id, @default_last_product_id),
      page: Keyword.get(opts, :page, @default_page)
    }
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/prodcatalog/product/list"
    Url.build_for_session(base_url, %{}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["catalog"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "catalog service URL not found", code: :service_not_found)}
    end
  end

  defp transform_response(data) when is_map(data) do
    %{
      items: data["items"] || data[:items] || [],
      version: data["version"] || data[:version],
      has_more: data["has_more"] || data[:has_more]
    }
  end
end
