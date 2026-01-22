defmodule ZcaEx.Api.Endpoints.GetAliasList do
  @moduledoc "Get list of friend aliases"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get list of friend aliases with default pagination (page 1, count 100).

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{items: list, update_time: integer}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec list(Session.t(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def list(session, credentials), do: list(1, 100, session, credentials)

  @doc """
  Get list of friend aliases with custom pagination.

  ## Parameters
    - page: Page number (positive integer, default 1)
    - count: Items per page (positive integer, default 100)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{items: list, update_time: integer}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec list(pos_integer(), pos_integer(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def list(page, _count, _session, _credentials)
      when not is_integer(page) or page < 1 do
    {:error, Error.new(:api, "page must be a positive integer", code: :invalid_input)}
  end

  def list(_page, count, _session, _credentials)
      when not is_integer(count) or count < 1 do
    {:error, Error.new(:api, "count must be a positive integer", code: :invalid_input)}
  end

  def list(page, count, session, credentials) do
    with {:ok, service_url} <- get_service_url(session) do
      params = build_params(page, count, credentials.imei)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, encrypted_params, session)

          case AccountClient.get(session.uid, url, credentials.user_agent) do
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

  @doc "Build URL for get alias list endpoint with encrypted params"
  @spec build_url(String.t(), String.t(), Session.t()) :: String.t()
  def build_url(service_url, encrypted_params, session) do
    base_url = service_url <> "/api/alias/list"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, service_url} ->
        base_url = service_url <> "/api/alias/list"
        {:ok, Url.build_for_session(base_url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params(pos_integer(), pos_integer(), String.t()) :: map()
  def build_params(page, count, imei) do
    %{
      page: page,
      count: count,
      imei: imei
    }
  end

  @doc "Transform response data"
  @spec transform_response(map()) :: map()
  def transform_response(data) when is_map(data) do
    items = data["items"] || data[:items] || []

    transformed_items =
      Enum.map(items, fn item ->
        %{
          user_id: item["userId"] || item[:userId] || item["user_id"] || item[:user_id],
          alias: item["alias"] || item[:alias]
        }
      end)

    %{
      items: transformed_items,
      update_time:
        data["updateTime"] || data[:updateTime] || data["update_time"] || data[:update_time]
    }
  end

  @spec get_service_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["alias"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "alias service URL not found", code: :service_not_found)}
    end
  end
end
