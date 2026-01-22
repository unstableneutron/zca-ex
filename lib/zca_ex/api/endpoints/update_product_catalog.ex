defmodule ZcaEx.Api.Endpoints.UpdateProductCatalog do
  @moduledoc """
  Update a product in the catalog.

  Note: This API is used for zBusiness accounts.
  Maximum 5 product photos are allowed.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @max_photos 5
  @default_currency_unit "₫"

  @doc """
  Update a product in the catalog.

  ## Parameters
    - catalog_id: Catalog ID (required, non-empty string)
    - product_id: Product ID (required, non-empty string)
    - product_name: Product name (required, non-empty string)
    - price: Product price (required, non-empty string)
    - description: Product description (required, non-empty string)
    - create_time: Creation timestamp in milliseconds (required, positive integer)
    - product_photos: List of product photo URLs (default: [], max 5)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{item: map(), version_ls_catalog: integer(), version_catalog: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec update(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          integer(),
          list(),
          Session.t(),
          Credentials.t()
        ) ::
          {:ok, map()} | {:error, Error.t()}
  def update(
        catalog_id,
        product_id,
        product_name,
        price,
        description,
        create_time,
        product_photos \\ [],
        session,
        credentials
      )

  def update(
        catalog_id,
        product_id,
        product_name,
        price,
        description,
        create_time,
        product_photos,
        session,
        credentials
      ) do
    with :ok <- validate_catalog_id(catalog_id),
         :ok <- validate_product_id(product_id),
         :ok <- validate_product_name(product_name),
         :ok <- validate_price(price),
         :ok <- validate_description(description),
         :ok <- validate_create_time(create_time),
         :ok <- validate_product_photos(product_photos),
         {:ok, service_url} <- get_service_url(session) do
      params =
        build_params(
          catalog_id,
          product_id,
          product_name,
          price,
          description,
          create_time,
          product_photos
        )

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

  defp validate_catalog_id(catalog_id) when is_binary(catalog_id) and byte_size(catalog_id) > 0,
    do: :ok

  defp validate_catalog_id(_),
    do: {:error, Error.new(:api, "catalog_id must be a non-empty string", code: :invalid_input)}

  defp validate_product_id(product_id) when is_binary(product_id) and byte_size(product_id) > 0,
    do: :ok

  defp validate_product_id(_),
    do: {:error, Error.new(:api, "product_id must be a non-empty string", code: :invalid_input)}

  defp validate_product_name(name) when is_binary(name) and byte_size(name) > 0, do: :ok

  defp validate_product_name(_),
    do: {:error, Error.new(:api, "product_name must be a non-empty string", code: :invalid_input)}

  defp validate_price(price) when is_binary(price) and byte_size(price) > 0, do: :ok

  defp validate_price(_),
    do: {:error, Error.new(:api, "price must be a non-empty string", code: :invalid_input)}

  defp validate_description(desc) when is_binary(desc) and byte_size(desc) > 0, do: :ok

  defp validate_description(_),
    do: {:error, Error.new(:api, "description must be a non-empty string", code: :invalid_input)}

  defp validate_create_time(create_time) when is_integer(create_time) and create_time > 0, do: :ok

  defp validate_create_time(_),
    do: {:error, Error.new(:api, "create_time must be a positive integer", code: :invalid_input)}

  defp validate_product_photos(photos) when is_list(photos) do
    cond do
      length(photos) > @max_photos ->
        {:error,
         Error.new(:api, "product_photos must have at most #{@max_photos} items",
           code: :invalid_input
         )}

      not Enum.all?(photos, &is_binary/1) ->
        {:error,
         Error.new(:api, "product_photos must contain only strings", code: :invalid_input)}

      true ->
        :ok
    end
  end

  defp validate_product_photos(_),
    do: {:error, Error.new(:api, "product_photos must be a list", code: :invalid_input)}

  @doc false
  def build_params(
        catalog_id,
        product_id,
        product_name,
        price,
        description,
        create_time,
        product_photos
      ) do
    %{
      catalog_id: catalog_id,
      product_id: product_id,
      product_name: product_name,
      price: price,
      description: description,
      product_photos: product_photos,
      currency_unit: @default_currency_unit,
      create_time: create_time
    }
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/prodcatalog/product/update"
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
