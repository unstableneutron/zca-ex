defmodule ZcaEx.Api.Endpoints.DeleteAvatar do
  @moduledoc "Delete avatar(s) from avatar list"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type delete_response :: %{
          deleted_photo_ids: [String.t()],
          error_map: map()
        }

  @doc """
  Delete avatar(s) from avatar list.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - photo_ids: Single photo ID or list of photo IDs to delete

  ## Returns
    - `{:ok, delete_response()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), String.t() | [String.t()]) ::
          {:ok, delete_response()} | {:error, Error.t()}
  def call(session, credentials, photo_ids) do
    photo_ids = if is_list(photo_ids), do: photo_ids, else: [photo_ids]

    with :ok <- validate_photo_ids(photo_ids) do
      params = build_params(photo_ids, credentials.imei)

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
  end

  @doc "Validate that photo IDs list is non-empty"
  @spec validate_photo_ids([String.t()]) :: :ok | {:error, Error.t()}
  def validate_photo_ids([]),
    do: {:error, %Error{message: "At least one photo ID is required", code: nil}}

  def validate_photo_ids(ids) when is_list(ids), do: :ok
  def validate_photo_ids(_), do: {:error, %Error{message: "Photo IDs must be a list", code: nil}}

  @doc "Build URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :profile) <> "/api/social/del-avatars"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :profile) <> "/api/social/del-avatars"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params([String.t()], String.t()) :: map()
  def build_params(photo_ids, imei) do
    del_photos = Enum.map(photo_ids, fn id -> %{photoId: id} end)

    %{
      delPhotos: Jason.encode!(del_photos),
      imei: imei
    }
  end

  @doc "Transform response to Elixir-friendly format"
  @spec transform_response(map()) :: delete_response()
  def transform_response(data) do
    %{
      deleted_photo_ids: data["delPhotoIds"] || data[:delPhotoIds] || [],
      error_map: data["errMap"] || data[:errMap] || %{}
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
