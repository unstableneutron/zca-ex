defmodule ZcaEx.Api.Endpoints.GetStickersDetail do
  @moduledoc "Get sticker details by ID"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type sticker_detail :: %{
          id: integer(),
          cate_id: integer(),
          type: integer(),
          text: String.t() | nil,
          uri: String.t() | nil,
          fkey: String.t() | nil,
          status: integer() | nil,
          sticker_url: String.t() | nil,
          sticker_sprite_url: String.t() | nil
        }

  @doc """
  Get details for one or more stickers.

  ## Parameters
    - `sticker_ids` - Single sticker ID or list of sticker IDs
    - `session` - The authenticated session
    - `credentials` - Account credentials

  ## Returns
    - `{:ok, [sticker_detail()]}` on success (failed requests are skipped)
    - `{:error, Error.t()}` on validation failure
  """
  @spec get(integer() | [integer()], Session.t(), Credentials.t()) ::
          {:ok, [sticker_detail()]} | {:error, Error.t()}
  def get(sticker_id, session, credentials) when is_integer(sticker_id) do
    get([sticker_id], session, credentials)
  end

  def get(sticker_ids, session, credentials) when is_list(sticker_ids) do
    with :ok <- validate_sticker_ids(sticker_ids) do
      results =
        Enum.reduce(sticker_ids, [], fn sid, acc ->
          case get_single(sid, session, credentials) do
            {:ok, detail} -> [detail | acc]
            {:error, _} -> acc
          end
        end)

      {:ok, Enum.reverse(results)}
    end
  end

  def get(_, _, _) do
    {:error, %Error{message: "sticker_ids must be an integer or list of integers", code: nil}}
  end

  @doc "Validate sticker IDs"
  @spec validate_sticker_ids([integer()]) :: :ok | {:error, Error.t()}
  def validate_sticker_ids([]), do: {:error, %Error{message: "sticker_ids cannot be empty", code: nil}}

  def validate_sticker_ids(sticker_ids) when is_list(sticker_ids) do
    if Enum.all?(sticker_ids, &(is_integer(&1) and &1 > 0)) do
      :ok
    else
      {:error, %Error{message: "All sticker_ids must be positive integers", code: nil}}
    end
  end

  @doc "Build params for single sticker request"
  @spec build_params(integer()) :: map()
  def build_params(sticker_id) do
    %{sid: sticker_id}
  end

  @doc "Build base URL for sticker detail endpoint"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    service_url = get_service_url(session)
    "#{service_url}/api/message/sticker/sticker_detail"
  end

  @doc "Build full URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = build_base_url(session)
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Transform API response to sticker_detail map"
  @spec transform_detail(map()) :: sticker_detail()
  def transform_detail(data) do
    %{
      id: data["id"] || data[:id],
      cate_id: data["cateId"] || data[:cateId] || data["cate_id"] || data[:cate_id],
      type: data["type"] || data[:type],
      text: data["text"] || data[:text],
      uri: data["uri"] || data[:uri],
      fkey: data["fkey"] || data[:fkey],
      status: data["status"] || data[:status],
      sticker_url: data["stickerUrl"] || data[:stickerUrl] || data["sticker_url"] || data[:sticker_url],
      sticker_sprite_url: data["stickerSpriteUrl"] || data[:stickerSpriteUrl] || data["sticker_sprite_url"] || data[:sticker_sprite_url]
    }
  end

  defp get_single(sticker_id, session, credentials) do
    params = build_params(sticker_id)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
          {:ok, response} ->
            case Response.parse(response, session.secret_key) do
              {:ok, data} -> {:ok, transform_detail(data)}
              {:error, _} = error -> error
            end

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["sticker"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> "https://sticker.zalo.me"
    end
  end
end
