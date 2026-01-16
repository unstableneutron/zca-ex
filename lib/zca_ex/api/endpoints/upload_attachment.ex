defmodule ZcaEx.Api.Endpoints.UploadAttachment do
  @moduledoc """
  Upload files (images, videos, other files) to Zalo.

  ## File Types
  - Images (jpg, jpeg, png, webp): Immediate response with URLs
  - Videos (mp4): Async response via WebSocket event `:upload_attachment`
  - Other files: Async response via WebSocket event `:upload_attachment`

  ## Example

      # Upload from file path
      UploadAttachment.upload("/path/to/image.jpg", "thread_id", :user, session, creds)

      # Upload from binary data with image dimensions
      source = AttachmentSource.from_binary(data, "photo.jpg", width: 800, height: 600, total_size: 12345)
      UploadAttachment.upload(source, "thread_id", :user, session, creds)

      # Upload multiple files
      UploadAttachment.upload(["/path/1.jpg", "/path/2.png"], "thread_id", :group, session, creds)

  ## Async Uploads (Video/Files)
  For videos and files, the upload response only contains `file_id`. The full response
  (including `file_url`) comes via WebSocket. Subscribe to `:upload_attachment` events
  using `ZcaEx.Events` to receive the complete response.

  ## Image Metadata Note
  When uploading images from a file path, width/height metadata is **not** automatically
  extracted (unlike the JS version which uses getImageMetaData). For path-based image
  uploads, the `width` and `height` fields in the response will be `nil`.

  To include image dimensions, use `AttachmentSource.from_binary/3` with explicit
  `width` and `height` options:

      {:ok, data} = File.read("/path/to/image.jpg")
      source = AttachmentSource.from_binary(data, "image.jpg", width: 800, height: 600)
      UploadAttachment.upload(source, thread_id, :user, session, creds)

  ## Large File Note
  For files larger than 50MB, consider implementing a streaming approach to reduce
  memory usage. The current implementation loads the entire file into memory before
  chunking, which may cause issues with very large files.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Model.Attachment
  alias ZcaEx.Model.Attachment.{AttachmentSource, ImageResponse, VideoResponse, FileResponse}
  alias ZcaEx.Account.Session
  alias ZcaEx.Crypto.MD5
  alias ZcaEx.Error

  @type source :: String.t() | AttachmentSource.t()
  @type upload_result ::
          {:ok, [Attachment.upload_response()]}
          | {:error, Error.t()}

  @default_chunk_size 512 * 1024
  @default_max_files 20
  @default_max_size_mb 100
  @default_restricted_ext ~w(exe msi bat cmd com scr)

  @doc """
  Upload one or more files to a thread.

  ## Parameters
  - `sources` - file path(s) or `AttachmentSource` struct(s)
  - `thread_id` - user ID or group ID
  - `thread_type` - `:user` or `:group`
  - `session` - authenticated session
  - `credentials` - account credentials

  ## Returns
  - `{:ok, responses}` - list of upload responses (ImageResponse/VideoResponse/FileResponse)
  - `{:error, error}` - validation or request error
  """
  @spec upload(source() | [source()], String.t(), :user | :group, Session.t(), Credentials.t()) ::
          upload_result()
  def upload(sources, thread_id, thread_type, session, credentials)

  def upload(source, thread_id, thread_type, session, creds) when not is_list(source) do
    upload([source], thread_id, thread_type, session, creds)
  end

  def upload([], _thread_id, _thread_type, _session, _creds) do
    {:error, Error.api(nil, "Missing sources")}
  end

  def upload(sources, thread_id, thread_type, session, creds) when is_list(sources) do
    settings = get_sharefile_settings(session)

    with :ok <- validate_sources(sources),
         :ok <- validate_thread_id(thread_id),
         :ok <- validate_file_count(sources, settings),
         {:ok, attachments} <- prepare_attachments(sources, settings) do
      upload_all(attachments, thread_id, thread_type, session, creds, settings)
    end
  end

  defp get_sharefile_settings(session) do
    sharefile = get_in(session.settings, ["features", "sharefile"]) || %{}
    chunk_size = sharefile["chunk_size_file"]

    chunk_size =
      if is_integer(chunk_size) and chunk_size > 0,
        do: chunk_size,
        else: @default_chunk_size

    %{
      chunk_size: chunk_size,
      max_files: sharefile["max_file"] || @default_max_files,
      max_size_mb: sharefile["max_size_share_file_v3"] || @default_max_size_mb,
      restricted_ext: (sharefile["restricted_ext_file"] || @default_restricted_ext) |> Enum.map(&String.downcase/1)
    }
  end

  defp validate_sources([]), do: {:error, Error.api(nil, "Missing sources")}

  defp validate_sources(sources) do
    Enum.reduce_while(sources, :ok, fn source, :ok ->
      case validate_source(source) do
        :ok -> {:cont, :ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp validate_source(path) when is_binary(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, Error.api(nil, "File not found: #{path}")}
    end
  end

  defp validate_source(%AttachmentSource{type: :path, path: path}) do
    validate_source(path)
  end

  defp validate_source(%AttachmentSource{type: :binary, data: data, filename: filename})
       when is_binary(data) and is_binary(filename) do
    :ok
  end

  defp validate_source(_) do
    {:error, Error.api(nil, "Invalid source type")}
  end

  defp validate_thread_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  defp validate_thread_id(_), do: {:error, Error.api(nil, "Missing threadId")}

  defp validate_file_count(sources, settings) do
    if length(sources) > settings.max_files do
      {:error, Error.api(nil, "Exceed maximum file count of #{settings.max_files}")}
    else
      :ok
    end
  end

  defp prepare_attachments(sources, settings) do
    result =
      Enum.reduce_while(sources, {:ok, []}, fn source, {:ok, acc} ->
        case prepare_attachment(source, settings) do
          {:ok, attachment} -> {:cont, {:ok, [attachment | acc]}}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:ok, attachments} -> {:ok, Enum.reverse(attachments)}
      error -> error
    end
  end

  defp prepare_attachment(path, settings) when is_binary(path) do
    prepare_attachment(AttachmentSource.from_path(path), settings)
  end

  defp prepare_attachment(%AttachmentSource{} = source, settings) do
    filename = source.filename
    ext = Attachment.get_extension(filename)
    file_type = Attachment.detect_file_type(filename)

    with :ok <- validate_extension(ext, settings),
         {:ok, file_data, data} <- read_file_data(source, file_type),
         :ok <- validate_file_size(file_data.total_size, filename, settings) do
      {:ok,
       %{
         source: source,
         file_type: file_type,
         file_data: file_data,
         data: data,
         filename: filename
       }}
    end
  end

  defp validate_extension(ext, settings) do
    if ext in settings.restricted_ext do
      {:error, Error.api(nil, "File extension \"#{ext}\" is not allowed")}
    else
      :ok
    end
  end

  defp read_file_data(%AttachmentSource{type: :path, path: path}, file_type) do
    case File.read(path) do
      {:ok, data} ->
        file_data = build_file_data(Path.basename(path), byte_size(data), file_type, nil)
        {:ok, file_data, data}

      {:error, reason} ->
        {:error, Error.api(nil, "Failed to read file: #{reason}")}
    end
  end

  defp read_file_data(%AttachmentSource{type: :binary, data: data, filename: filename, metadata: metadata}, file_type) do
    total_size = byte_size(data)
    file_data = build_file_data(filename, total_size, file_type, metadata)
    {:ok, file_data, data}
  end

  defp build_file_data(filename, total_size, :image, metadata) do
    %{
      file_name: filename,
      total_size: total_size,
      width: metadata[:width],
      height: metadata[:height]
    }
  end

  defp build_file_data(filename, total_size, _file_type, _metadata) do
    %{
      file_name: filename,
      total_size: total_size
    }
  end

  defp validate_file_size(0, filename, _settings) do
    {:error, Error.api(nil, "Empty file not allowed: #{filename}")}
  end

  defp validate_file_size(size, filename, settings) do
    max_bytes = settings.max_size_mb * 1024 * 1024

    if size > max_bytes do
      {:error, Error.api(nil, "File #{filename} size exceeds maximum size of #{settings.max_size_mb}MB")}
    else
      :ok
    end
  end

  defp upload_all(attachments, thread_id, thread_type, session, creds, settings) do
    case get_base_url(session, thread_type) do
      {:error, _} = err ->
        err

      {:ok, base_url} ->
        type_param = if thread_type == :group, do: "11", else: "2"

        client_id_start = System.system_time(:millisecond)

        results =
          attachments
          |> Enum.with_index()
          |> Enum.map(fn {attachment, idx} ->
            client_id = client_id_start + idx

            upload_attachment(
              attachment,
              thread_id,
              thread_type,
              base_url,
              type_param,
              client_id,
              session,
              creds,
              settings
            )
          end)

        errors = Enum.filter(results, &match?({:error, _}, &1))

        if errors == [] do
          {:ok, Enum.map(results, fn {:ok, resp} -> resp end)}
        else
          hd(errors)
        end
    end
  end

  defp get_base_url(session, _thread_type) do
    case get_in(session.zpw_service_map, ["file", Access.at(0)]) do
      nil -> {:error, Error.api(nil, "Missing file service URL in session")}
      url -> {:ok, url <> "/api"}
    end
  end

  defp upload_attachment(attachment, thread_id, thread_type, base_url, type_param, client_id, session, creds, settings) do
    %{file_type: file_type, file_data: file_data, data: data, filename: filename} = attachment

    url_path = Attachment.url_path_for_type(file_type)
    thread_prefix = if thread_type == :group, do: "group", else: "message"
    full_url = "#{base_url}/#{thread_prefix}/#{url_path}"

    chunks = split_into_chunks(data, settings.chunk_size)
    total_chunks = length(chunks)

    params = build_upload_params(
      thread_id,
      thread_type,
      filename,
      file_data.total_size,
      total_chunks,
      client_id,
      creds.imei
    )

    upload_chunks(
      chunks,
      params,
      full_url,
      type_param,
      file_type,
      file_data,
      data,
      session,
      creds
    )
  end

  @doc "Split binary data into chunks"
  @spec split_into_chunks(binary(), pos_integer()) :: [binary()]
  def split_into_chunks(data, chunk_size) do
    do_split_chunks(data, chunk_size, [])
  end

  defp do_split_chunks(<<>>, _chunk_size, acc), do: Enum.reverse(acc)

  defp do_split_chunks(data, chunk_size, acc) do
    case data do
      <<chunk::binary-size(chunk_size), rest::binary>> ->
        do_split_chunks(rest, chunk_size, [chunk | acc])

      remaining ->
        Enum.reverse([remaining | acc])
    end
  end

  defp build_upload_params(thread_id, thread_type, filename, total_size, total_chunks, client_id, imei) do
    base = %{
      totalChunk: total_chunks,
      fileName: filename,
      clientId: client_id,
      totalSize: total_size,
      imei: imei,
      isE2EE: 0,
      jxl: 0,
      chunkId: 1
    }

    if thread_type == :group do
      Map.put(base, :grid, thread_id)
    else
      Map.put(base, :toid, thread_id)
    end
  end

  defp upload_chunks(chunks, params, full_url, type_param, file_type, file_data, full_data, session, creds) do
    result =
      chunks
      |> Enum.with_index(1)
      |> Enum.reduce_while(nil, fn {chunk, chunk_id}, _acc ->
        chunk_params = Map.put(params, :chunkId, chunk_id)

        case upload_single_chunk(chunk, chunk_params, full_url, type_param, session, creds) do
          {:ok, response} -> {:cont, {:ok, response}}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:ok, response} ->
        build_response(response, file_type, file_data, full_data)

      {:error, _} = err ->
        err
    end
  end

  defp upload_single_chunk(chunk_data, params, full_url, type_param, session, creds) do
    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = Url.build(full_url, %{type: type_param, params: encrypted_params}, nretry: 0, api_type: session.api_type, version: session.api_version)

        parts = [
          {"chunkContent", chunk_data, filename: params.fileName, content_type: "application/octet-stream"}
        ]

        case AccountClient.post_multipart(creds.imei, url, parts, creds.user_agent) do
          {:ok, response} ->
            Response.parse_unencrypted(response)

          {:error, reason} ->
            {:error, Error.network("Upload request failed: #{inspect(reason)}")}
        end

      {:error, _} = err ->
        err
    end
  end

  defp build_response(response, :image, file_data, _full_data) do
    {:ok, ImageResponse.from_response(response, file_data)}
  end

  defp build_response(response, :video, file_data, full_data) do
    checksum = MD5.hash_hex(full_data)
    {:ok, VideoResponse.from_response(response, file_data, checksum)}
  end

  defp build_response(response, :file, file_data, full_data) do
    checksum = MD5.hash_hex(full_data)
    {:ok, FileResponse.from_response(response, file_data, checksum)}
  end
end
