defmodule ZcaEx.Api.Endpoints.UpdateCatalog do
  @moduledoc """
  Update a catalog.

  Note: This API is used for zBusiness accounts.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Update a catalog.

  ## Parameters
    - catalog_id: The catalog ID (non-empty string)
    - catalog_name: The new catalog name (non-empty string)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{item: map(), version_ls_catalog: integer(), version_catalog: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec update(String.t(), String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def update(catalog_id, catalog_name, session, credentials) do
    with :ok <- validate_catalog_id(catalog_id),
         :ok <- validate_catalog_name(catalog_name),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(catalog_id, catalog_name)

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

  defp validate_catalog_name(catalog_name) when is_binary(catalog_name) and byte_size(catalog_name) > 0, do: :ok
  defp validate_catalog_name(_), do: {:error, Error.new(:api, "catalog_name must be a non-empty string", code: :invalid_input)}

  @doc false
  def build_params(catalog_id, catalog_name) do
    %{
      catalog_id: catalog_id,
      catalog_name: catalog_name,
      catalog_photo: ""
    }
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/prodcatalog/catalog/update"
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
