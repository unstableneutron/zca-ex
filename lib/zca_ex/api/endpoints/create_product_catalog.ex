defmodule ZcaEx.Api.Endpoints.CreateProductCatalog do
  @moduledoc """
  Create a product in a catalog.

  Creates a new product with name, price, description, and optional photos.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @max_photos 5
  @default_currency "₫"

  @doc """
  Create a product in a catalog without photos.

  See `create/7` for details.
  """
  @spec create(String.t(), String.t(), String.t(), String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def create(catalog_id, product_name, price, description, session, credentials) do
    create(catalog_id, product_name, price, description, [], session, credentials)
  end

  @doc """
  Create a product in a catalog.

  ## Parameters
    - catalog_id: Catalog ID (non-empty string)
    - product_name: Product name (non-empty string)
    - price: Product price (non-empty string)
    - description: Product description (non-empty string)
    - product_photos: List of photo URLs (max 5, defaults to [])
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{item: map, version_ls_catalog: integer, version_catalog: integer}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec create(String.t(), String.t(), String.t(), String.t(), [String.t()], Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def create(catalog_id, product_name, price, description, product_photos, session, credentials) do
    with :ok <- validate_catalog_id(catalog_id),
         :ok <- validate_product_name(product_name),
         :ok <- validate_price(price),
         :ok <- validate_description(description),
         :ok <- validate_product_photos(product_photos),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(catalog_id, product_name, price, description, product_photos)

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

  defp validate_product_name(product_name) when is_binary(product_name) and byte_size(product_name) > 0, do: :ok
  defp validate_product_name(_), do: {:error, Error.new(:api, "product_name must be a non-empty string", code: :invalid_input)}

  defp validate_price(price) when is_binary(price) and byte_size(price) > 0, do: :ok
  defp validate_price(_), do: {:error, Error.new(:api, "price must be a non-empty string", code: :invalid_input)}

  defp validate_description(description) when is_binary(description) and byte_size(description) > 0, do: :ok
  defp validate_description(_), do: {:error, Error.new(:api, "description must be a non-empty string", code: :invalid_input)}

  defp validate_product_photos(photos) when is_list(photos) and length(photos) <= @max_photos, do: :ok
  defp validate_product_photos(photos) when is_list(photos), do: {:error, Error.new(:api, "product_photos must have at most #{@max_photos} items", code: :invalid_input)}
  defp validate_product_photos(_), do: {:error, Error.new(:api, "product_photos must be a list", code: :invalid_input)}

  @doc false
  def build_params(catalog_id, product_name, price, description, product_photos) do
    %{
      catalog_id: catalog_id,
      product_name: product_name,
      price: price,
      description: description,
      product_photos: product_photos,
      currency_unit: @default_currency,
      create_time: System.system_time(:millisecond)
    }
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/prodcatalog/product/create"
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
      item: data["item"] || data[:item],
      version_ls_catalog: data["version_ls_catalog"] || data[:version_ls_catalog],
      version_catalog: data["version_catalog"] || data[:version_catalog]
    }
  end
end
