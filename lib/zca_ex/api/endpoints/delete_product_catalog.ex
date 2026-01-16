defmodule ZcaEx.Api.Endpoints.DeleteProductCatalog do
  @moduledoc """
  Delete products from a catalog.

  Supports deleting single or multiple products at once.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Delete products from a catalog.

  ## Parameters
    - catalog_id: Catalog ID (non-empty string)
    - product_ids: Single product ID string or list of product ID strings (non-empty)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{item: list(integer), version_ls_catalog: integer, version_catalog: integer}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec delete(String.t(), String.t() | [String.t()], Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def delete(catalog_id, product_ids, session, credentials) do
    with :ok <- validate_catalog_id(catalog_id),
         {:ok, normalized_ids} <- validate_and_normalize_product_ids(product_ids),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(catalog_id, normalized_ids)

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

  defp validate_and_normalize_product_ids(product_id) when is_binary(product_id) and byte_size(product_id) > 0 do
    {:ok, [product_id]}
  end

  defp validate_and_normalize_product_ids(product_ids) when is_list(product_ids) and length(product_ids) > 0 do
    if Enum.all?(product_ids, &(is_binary(&1) and byte_size(&1) > 0)) do
      {:ok, product_ids}
    else
      {:error, Error.new(:api, "all product_ids must be non-empty strings", code: :invalid_input)}
    end
  end

  defp validate_and_normalize_product_ids([]) do
    {:error, Error.new(:api, "product_ids must not be empty", code: :invalid_input)}
  end

  defp validate_and_normalize_product_ids("") do
    {:error, Error.new(:api, "product_ids must be a non-empty string or non-empty list of strings", code: :invalid_input)}
  end

  defp validate_and_normalize_product_ids(_) do
    {:error, Error.new(:api, "product_ids must be a non-empty string or non-empty list of strings", code: :invalid_input)}
  end

  @doc false
  def build_params(catalog_id, product_ids) do
    %{
      catalog_id: catalog_id,
      product_ids: product_ids
    }
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/prodcatalog/product/mdelete"
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
