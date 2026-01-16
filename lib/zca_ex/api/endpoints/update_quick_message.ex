defmodule ZcaEx.Api.Endpoints.UpdateQuickMessage do
  @moduledoc "Update a quick message"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Update a quick message (text only).

  ## Parameters
    - item_id: Quick message ID (positive integer)
    - keyword: Trigger keyword (non-empty string)
    - title: Message content (non-empty string)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{item: map(), version: integer()}}` on success
    - `{:error, Error.t()}` on failure

  ## Notes
    - Error code 212 indicates item_id does not exist
  """
  @spec update(integer(), String.t(), String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def update(item_id, _keyword, _title, _session, _credentials)
      when not is_integer(item_id) or item_id <= 0 do
    {:error, Error.new(:api, "item_id must be a positive integer", code: :invalid_input)}
  end

  def update(_item_id, keyword, _title, _session, _credentials)
      when not is_binary(keyword) or keyword == "" do
    {:error, Error.new(:api, "keyword must be a non-empty string", code: :invalid_input)}
  end

  def update(_item_id, _keyword, title, _session, _credentials)
      when not is_binary(title) or title == "" do
    {:error, Error.new(:api, "title must be a non-empty string", code: :invalid_input)}
  end

  def update(item_id, keyword, title, session, credentials) do
    with {:ok, service_url} <- get_service_url(session) do
      params = build_params(item_id, keyword, title, credentials)

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

  @doc false
  def build_params(item_id, keyword, title, credentials) do
    %{
      itemId: item_id,
      keyword: keyword,
      message: %{
        title: title,
        params: ""
      },
      type: 0,
      imei: credentials.imei
    }
  end

  @doc false
  def build_url(service_url, encrypted_params, session) do
    base_url = service_url <> "/api/quickmessage/update"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["quick_message"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "quick_message service URL not found", code: :service_not_found)}
    end
  end

  defp transform_response(data) when is_map(data) do
    %{
      item: data["item"] || data[:item],
      version: data["version"] || data[:version]
    }
  end
end
