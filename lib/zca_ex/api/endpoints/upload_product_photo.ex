defmodule ZcaEx.Api.Endpoints.UploadProductPhoto do
  @moduledoc """
  Upload product photo for quick message, product catalog, or custom local storage.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type response :: %{
          normal_url: String.t(),
          photo_id: String.t(),
          finished: integer(),
          hd_url: String.t(),
          thumb_url: String.t(),
          client_file_id: integer(),
          chunk_id: integer()
        }

  @doc """
  Upload a product photo.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - image_data: Binary image data
    - opts: Options
      - `:file_name` - Custom file name (default: auto-generated)

  ## Returns
    - `{:ok, response()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec upload(Session.t(), Credentials.t(), binary(), keyword()) ::
          {:ok, response()} | {:error, Error.t()}
  def upload(session, credentials, image_data, opts \\ []) do
    with :ok <- validate_image_data(image_data),
         {:ok, toid} <- get_send2me_id(session),
         {:ok, service_url} <- get_service_url(session) do
      now = System.system_time(:millisecond)
      file_name = Keyword.get(opts, :file_name, "Base64_Img_Picker_#{now}.jpg")
      total_size = byte_size(image_data)

      params = build_params(file_name, now, total_size, credentials.imei, toid)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, encrypted_params, session)
          parts = [{"chunkContent", image_data, filename: "undefined", content_type: "application/octet-stream"}]

          case AccountClient.post_multipart(session.uid, url, parts, credentials.user_agent) do
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

  defp validate_image_data(data) when is_binary(data) and byte_size(data) > 0, do: :ok
  defp validate_image_data(nil), do: {:error, Error.new(:api, "image_data is required", code: :invalid_input)}
  defp validate_image_data(<<>>), do: {:error, Error.new(:api, "image_data cannot be empty", code: :invalid_input)}
  defp validate_image_data(_), do: {:error, Error.new(:api, "image_data must be a binary", code: :invalid_input)}

  @doc false
  def build_params(file_name, client_id, total_size, imei, toid) do
    %{
      totalChunk: 1,
      fileName: file_name,
      clientId: client_id,
      totalSize: total_size,
      imei: imei,
      chunkId: 1,
      toid: toid,
      featureId: 1
    }
  end

  @doc false
  def build_url(service_url, encrypted_params, session) do
    base_url = service_url <> "/api/product/upload/photo"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["file"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "file service URL not found", code: :service_not_found)}
    end
  end

  defp get_send2me_id(session) do
    case get_in(session.login_info, ["send2me_id"]) || get_in(session.login_info, [:send2me_id]) do
      nil -> {:error, Error.new(:api, "send2me_id missing from session", code: :invalid_input)}
      "" -> {:error, Error.new(:api, "send2me_id missing from session", code: :invalid_input)}
      id when is_binary(id) -> {:ok, id}
      _ -> {:error, Error.new(:api, "send2me_id missing from session", code: :invalid_input)}
    end
  end

  defp transform_response(data) when is_map(data) do
    %{
      normal_url: data["normalUrl"] || data[:normalUrl] || "",
      photo_id: data["photoId"] || data[:photoId] || "",
      finished: data["finished"] || data[:finished] || 0,
      hd_url: data["hdUrl"] || data[:hdUrl] || "",
      thumb_url: data["thumbUrl"] || data[:thumbUrl] || "",
      client_file_id: data["clientFileId"] || data[:clientFileId] || 0,
      chunk_id: data["chunkId"] || data[:chunkId] || 0
    }
  end
end
