defmodule ZcaEx.Api.Endpoints.DeleteCatalog do
  @moduledoc """
  Delete a catalog.

  Note: This API is used for zBusiness accounts.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Delete a catalog.

  ## Parameters
    - catalog_id: The catalog ID (non-empty string)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, ""}` on success (empty string)
    - `{:error, Error.t()}` on failure
  """
  @spec delete(String.t(), Session.t(), Credentials.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def delete(catalog_id, session, credentials) do
    with :ok <- validate_catalog_id(catalog_id),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(catalog_id)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, data} -> {:ok, data}
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

  @doc false
  def build_params(catalog_id) do
    %{
      catalog_id: catalog_id
    }
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/prodcatalog/catalog/delete"
    Url.build_for_session(base_url, %{}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["catalog"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "catalog service URL not found", code: :service_not_found)}
    end
  end
end
