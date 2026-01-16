defmodule ZcaEx.Api.Endpoints.GetCatalogList do
  @moduledoc """
  Get the list of product catalogs.

  Note: This API is used for zBusiness accounts.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @default_limit 20
  @default_last_product_id -1
  @default_page 0

  @doc """
  Get the list of product catalogs.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Optional keyword list
      - `:limit` - Number of items to retrieve (default: 20, must be positive)
      - `:last_product_id` - Last product ID for pagination (default: -1)
      - `:page` - Page number (default: 0, must be non-negative)

  ## Returns
    - `{:ok, %{items: list(), version: integer(), has_more: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec list(Session.t(), Credentials.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(session, credentials, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    last_product_id = Keyword.get(opts, :last_product_id, @default_last_product_id)
    page = Keyword.get(opts, :page, @default_page)

    with :ok <- validate_limit(limit),
         :ok <- validate_page(page),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(limit, last_product_id, page)

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

  defp validate_limit(limit) when is_integer(limit) and limit > 0, do: :ok
  defp validate_limit(_), do: {:error, Error.new(:api, "limit must be a positive integer", code: :invalid_input)}

  defp validate_page(page) when is_integer(page) and page >= 0, do: :ok
  defp validate_page(_), do: {:error, Error.new(:api, "page must be a non-negative integer", code: :invalid_input)}

  @doc false
  def build_params(limit, last_product_id, page) do
    %{
      version_list_catalog: 0,
      limit: limit,
      last_product_id: last_product_id,
      page: page
    }
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/prodcatalog/catalog/list"
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
