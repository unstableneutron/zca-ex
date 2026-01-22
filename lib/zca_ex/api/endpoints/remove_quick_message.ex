defmodule ZcaEx.Api.Endpoints.RemoveQuickMessage do
  @moduledoc "Remove quick message(s)"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Remove one or more quick messages.

  ## Parameters
    - item_ids: Quick message ID(s) - single integer or list of integers
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{item_ids: list(), version: integer()}}` on success
    - `{:error, Error.t()}` on failure

  ## Notes
    - Error code 212 indicates item does not exist
  """
  @spec remove(integer() | [integer()], Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def remove(item_ids, session, credentials) do
    with {:ok, ids_list} <- validate_item_ids(item_ids),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(ids_list, credentials)

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

  defp validate_item_ids(item_id) when is_integer(item_id) and item_id > 0 do
    {:ok, [item_id]}
  end

  defp validate_item_ids(item_ids) when is_list(item_ids) do
    if Enum.all?(item_ids, fn id -> is_integer(id) and id > 0 end) and length(item_ids) > 0 do
      {:ok, item_ids}
    else
      {:error, Error.new(:api, "item_ids must be positive integers", code: :invalid_input)}
    end
  end

  defp validate_item_ids(_) do
    {:error,
     Error.new(:api, "item_ids must be a positive integer or list of positive integers",
       code: :invalid_input
     )}
  end

  @doc false
  def build_params(item_ids, credentials) do
    %{
      itemIds: item_ids,
      imei: credentials.imei
    }
  end

  @doc false
  def build_url(service_url, encrypted_params, session) do
    base_url = service_url <> "/api/quickmessage/delete"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["quick_message"]) do
      [url | _] when is_binary(url) ->
        {:ok, url}

      url when is_binary(url) ->
        {:ok, url}

      _ ->
        {:error, Error.new(:api, "quick_message service URL not found", code: :service_not_found)}
    end
  end

  defp transform_response(data) when is_map(data) do
    %{
      item_ids: data["itemIds"] || data[:itemIds] || data["item_ids"] || data[:item_ids] || [],
      version: data["version"] || data[:version]
    }
  end
end
