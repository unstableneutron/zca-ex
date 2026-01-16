defmodule ZcaEx.Api.Endpoints.GetListBoard do
  @moduledoc "Get list of boards for a group"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @default_page 1
  @default_count 20

  @poll_board_type 1

  @doc """
  Get list of boards for a group.

  ## Parameters
    - group_id: The group ID (non-empty string)
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Options
      - `:page` - Page number (default: 1, positive integer)
      - `:count` - Number of items per page (default: 20, positive integer)

  ## Returns
    - `{:ok, %{items: list(), count: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), Session.t(), Credentials.t(), keyword()) ::
          {:ok, %{items: list(), count: integer()}} | {:error, Error.t()}
  def call(group_id, session, credentials, opts \\ []) do
    with :ok <- validate_group_id(group_id),
         {:ok, page} <- validate_page(Keyword.get(opts, :page, @default_page)),
         {:ok, count} <- validate_count(Keyword.get(opts, :count, @default_count)),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(group_id, page, count, credentials.imei)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, session, encrypted_params)

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

  @doc "Build URL for get list board endpoint with encrypted params"
  @spec build_url(String.t(), Session.t(), String.t()) :: String.t()
  def build_url(service_url, session, encrypted_params) do
    url = service_url <> "/api/board/list"
    Url.build_for_session(url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, service_url} ->
        url = service_url <> "/api/board/list"
        {:ok, Url.build_for_session(url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), integer(), integer(), String.t()) :: map()
  def build_params(group_id, page, count, imei) do
    %{
      group_id: group_id,
      board_type: 0,
      page: page,
      count: count,
      last_id: 0,
      last_type: 0,
      imei: imei
    }
  end

  @doc "Transform response data, parsing nested JSON in items[].data.params"
  @spec transform_response(map()) :: %{items: list(), count: integer()}
  def transform_response(data) when is_map(data) do
    items = data["items"] || data[:items] || []
    count = data["count"] || data[:count] || 0

    transformed_items =
      Enum.map(items, fn item ->
        transform_item(item)
      end)

    %{
      items: transformed_items,
      count: count
    }
  end

  defp transform_item(item) when is_map(item) do
    board_type = item["boardType"] || item[:boardType] || item["board_type"] || item[:board_type]
    data = item["data"] || item[:data] || %{}

    transformed_data = transform_item_data(board_type, data)

    %{
      board_type: board_type,
      data: transformed_data
    }
  end

  defp transform_item(_item), do: %{board_type: nil, data: %{}}

  defp transform_item_data(board_type, data) when is_map(data) and board_type != @poll_board_type do
    params_key = cond do
      Map.has_key?(data, "params") -> "params"
      Map.has_key?(data, :params) -> :params
      true -> nil
    end

    case params_key do
      nil ->
        data

      key ->
        case Map.get(data, key) do
          params when is_binary(params) ->
            case Jason.decode(params) do
              {:ok, parsed} ->
                data
                |> Map.delete("params")
                |> Map.delete(:params)
                |> Map.put(:params, parsed)

              {:error, _} ->
                data
            end

          _ ->
            data
        end
    end
  end

  defp transform_item_data(_board_type, data), do: data

  defp validate_group_id(group_id) when is_binary(group_id) and byte_size(group_id) > 0, do: :ok

  defp validate_group_id(_),
    do: {:error, Error.new(:api, "group_id must be a non-empty string", code: :invalid_input)}

  defp validate_page(page) when is_integer(page) and page >= 1, do: {:ok, page}

  defp validate_page(_),
    do: {:error, Error.new(:api, "page must be a positive integer", code: :invalid_input)}

  defp validate_count(count) when is_integer(count) and count >= 1, do: {:ok, count}

  defp validate_count(_),
    do: {:error, Error.new(:api, "count must be a positive integer", code: :invalid_input)}

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["group_board"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "group_board service URL not found", code: :service_not_found)}
    end
  end
end
