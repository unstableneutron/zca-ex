defmodule ZcaEx.Api.Endpoints.ReuseAvatar do
  @moduledoc "Reuse an avatar from the avatar list"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Reuse an avatar from the avatar list.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - photo_id: Photo ID from GetAvatarList

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), String.t()) ::
          {:ok, :success} | {:error, Error.t()}
  def call(session, credentials, photo_id) do
    with :ok <- validate_photo_id(photo_id) do
      params = build_params(photo_id, credentials.imei)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(session, encrypted_params)

          case AccountClient.get(session.uid, url, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, _data} -> {:ok, :success}
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

  @spec validate_photo_id(term()) :: :ok | {:error, Error.t()}
  def validate_photo_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  def validate_photo_id(_), do: {:error, %Error{message: "Photo ID must be a non-empty string", code: nil}}

  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :profile) <> "/api/social/reuse-avatar"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :profile) <> "/api/social/reuse-avatar"
    Url.build_for_session(base_url, %{}, session)
  end

  @spec build_params(String.t(), String.t()) :: map()
  def build_params(photo_id, imei) do
    %{
      photoId: photo_id,
      isPostSocial: 0,
      imei: imei
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
