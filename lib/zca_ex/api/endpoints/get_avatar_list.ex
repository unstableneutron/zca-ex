defmodule ZcaEx.Api.Endpoints.GetAvatarList do
  @moduledoc "Get list of account avatars"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @default_count 50
  @default_page 1

  @type photo :: %{
          photo_id: String.t(),
          thumbnail: String.t(),
          url: String.t(),
          backup_url: String.t()
        }

  @type avatar_list_response :: %{
          album_id: String.t(),
          next_photo_id: String.t(),
          has_more: boolean(),
          photos: [photo()]
        }

  @doc """
  Get list of account avatars.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Options
      - `:count` - Number of avatars to fetch (default: 50)
      - `:page` - Page number (default: 1)

  ## Returns
    - `{:ok, avatar_list_response()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), keyword()) ::
          {:ok, avatar_list_response()} | {:error, Error.t()}
  def call(session, credentials, opts \\ []) do
    count = Keyword.get(opts, :count, @default_count)
    page = Keyword.get(opts, :page, @default_page)

    params = build_params(page, count, credentials.imei)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
          {:ok, response} ->
            case Response.parse(response, session.secret_key) do
              {:ok, data} -> {:ok, transform_response(data)}
              {:error, _} = error -> error
            end

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :profile) <> "/api/social/avatar-list"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :profile) <> "/api/social/avatar-list"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(integer(), integer(), String.t()) :: map()
  def build_params(page, count, imei) do
    %{
      page: page,
      albumId: "0",
      count: count,
      imei: imei
    }
  end

  @doc "Transform response to Elixir-friendly format"
  @spec transform_response(map()) :: avatar_list_response()
  def transform_response(data) do
    photos = data["photos"] || data[:photos] || []

    %{
      album_id: data["albumId"] || data[:albumId] || "0",
      next_photo_id: data["nextPhotoId"] || data[:nextPhotoId] || "",
      has_more: (data["hasMore"] || data[:hasMore] || 0) == 1,
      photos: Enum.map(photos, &transform_photo/1)
    }
  end

  @doc "Transform a single photo to Elixir-friendly format"
  @spec transform_photo(map()) :: photo()
  def transform_photo(photo) do
    %{
      photo_id: photo["photoId"] || photo[:photoId],
      thumbnail: photo["thumbnail"] || photo[:thumbnail],
      url: photo["url"] || photo[:url],
      backup_url: photo["bkUrl"] || photo[:bkUrl]
    }
  end

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
