defmodule ZcaEx.Api.Endpoints.GetStickers do
  @moduledoc "Get sticker suggestions by keyword"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get sticker suggestions by keyword.

  ## Parameters
    - keyword: Search keyword (required, non-empty string)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, [integer()]}` list of sticker IDs on success
    - `{:error, Error.t()}` on failure
  """
  @spec get(String.t(), Session.t(), Credentials.t()) :: {:ok, [integer()]} | {:error, Error.t()}
  def get(keyword, session, credentials) do
    with :ok <- validate_keyword(keyword) do
      base_url = build_base_url(session)
      params = build_params(keyword, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted} ->
          url = build_url(base_url, encrypted, session)

          case AccountClient.get(session.uid, url, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, data} -> extract_sticker_ids(data)
                {:error, _} = error -> error
              end

            {:error, reason} ->
              {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "Validate keyword is non-empty string (after trimming whitespace)"
  @spec validate_keyword(any()) :: :ok | {:error, Error.t()}
  def validate_keyword(keyword) when is_binary(keyword) do
    trimmed = String.trim(keyword)
    if byte_size(trimmed) > 0 do
      :ok
    else
      {:error, %Error{message: "keyword is required and must be a non-empty string", code: nil}}
    end
  end

  def validate_keyword(_),
    do: {:error, %Error{message: "keyword is required and must be a non-empty string", code: nil}}

  @doc "Build params map for encryption"
  @spec build_params(String.t(), Credentials.t()) :: map()
  def build_params(keyword, credentials) do
    %{
      keyword: keyword,
      gif: 1,
      guggy: 0,
      imei: credentials.imei
    }
  end

  @doc "Build base URL from session service map"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    get_service_url(session) <> "/api/message/sticker/suggest/stickers"
  end

  @doc "Build full URL with encrypted params"
  @spec build_url(String.t(), String.t(), Session.t()) :: String.t()
  def build_url(base_url, encrypted_params, session) do
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Extract sticker IDs from response data"
  @spec extract_sticker_ids(map()) :: {:ok, [integer()]}
  def extract_sticker_ids(data) when is_map(data) do
    stickers = Map.get(data, "sugg_sticker") || Map.get(data, :sugg_sticker) || []

    ids =
      stickers
      |> Enum.map(fn sticker ->
        Map.get(sticker, "sticker_id") || Map.get(sticker, :sticker_id)
      end)
      |> Enum.filter(&is_integer/1)

    {:ok, ids}
  end

  def extract_sticker_ids(_), do: {:ok, []}

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["sticker"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> "https://sticker.zalo.me"
    end
  end
end
