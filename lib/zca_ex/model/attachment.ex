defmodule ZcaEx.Model.Attachment do
  @moduledoc """
  Attachment types for file uploads.

  ## Source Types

  - `AttachmentSource` - represents a file to upload (path or binary data)
  - `ImageResponse` - response for uploaded images
  - `VideoResponse` - response for uploaded videos
  - `FileResponse` - response for uploaded files (non-image, non-video)
  """

  defmodule AttachmentSource do
    @moduledoc """
    Represents a file to upload.

    Can be either:
    - A file path (string)
    - Binary data with metadata

    ## Examples

        # File path
        source = AttachmentSource.from_path("/path/to/file.jpg")

        # Binary data
        source = AttachmentSource.from_binary(data, "photo.jpg", width: 800, height: 600, total_size: 12345)
    """

    @type t :: %__MODULE__{
            type: :path | :binary,
            path: String.t() | nil,
            data: binary() | nil,
            filename: String.t(),
            metadata: metadata()
          }

    @type metadata :: %{
            optional(:width) => non_neg_integer(),
            optional(:height) => non_neg_integer(),
            optional(:total_size) => non_neg_integer()
          }

    defstruct [:type, :path, :data, :filename, metadata: %{}]

    @spec from_path(String.t()) :: t()
    def from_path(path) when is_binary(path) do
      %__MODULE__{
        type: :path,
        path: path,
        filename: Path.basename(path)
      }
    end

    @spec from_binary(binary(), String.t(), keyword()) :: t()
    def from_binary(data, filename, opts \\ []) when is_binary(data) and is_binary(filename) do
      metadata =
        %{}
        |> maybe_put(:width, Keyword.get(opts, :width))
        |> maybe_put(:height, Keyword.get(opts, :height))
        |> maybe_put(:total_size, Keyword.get(opts, :total_size))

      %__MODULE__{
        type: :binary,
        data: data,
        filename: filename,
        metadata: metadata
      }
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  defmodule ImageResponse do
    @moduledoc "Response for an uploaded image"

    @type t :: %__MODULE__{
            file_type: :image,
            normal_url: String.t() | nil,
            photo_id: String.t(),
            hd_url: String.t() | nil,
            thumb_url: String.t() | nil,
            width: non_neg_integer() | nil,
            height: non_neg_integer() | nil,
            total_size: non_neg_integer(),
            hd_size: non_neg_integer(),
            finished: boolean(),
            client_file_id: integer(),
            chunk_id: integer()
          }

    defstruct [
      :normal_url,
      :photo_id,
      :hd_url,
      :thumb_url,
      :width,
      :height,
      :total_size,
      :hd_size,
      :finished,
      :client_file_id,
      :chunk_id,
      file_type: :image
    ]

    @spec from_response(map(), map()) :: t()
    def from_response(response, file_data) do
      %__MODULE__{
        file_type: :image,
        normal_url: response["normalUrl"],
        photo_id: response["photoId"],
        hd_url: response["hdUrl"],
        thumb_url: response["thumbUrl"],
        width: file_data[:width] || file_data["width"],
        height: file_data[:height] || file_data["height"],
        total_size: file_data[:total_size] || file_data["totalSize"],
        hd_size: file_data[:total_size] || file_data["totalSize"],
        finished: normalize_finished(response["finished"]),
        client_file_id: response["clientFileId"],
        chunk_id: response["chunkId"]
      }
    end

    defp normalize_finished(1), do: true
    defp normalize_finished(0), do: false
    defp normalize_finished(true), do: true
    defp normalize_finished(false), do: false
    defp normalize_finished(_), do: false
  end

  defmodule VideoResponse do
    @moduledoc "Response for an uploaded video"

    @type t :: %__MODULE__{
            file_type: :video,
            file_url: String.t() | nil,
            file_id: String.t(),
            checksum: String.t(),
            total_size: non_neg_integer(),
            file_name: String.t(),
            finished: boolean(),
            client_file_id: integer(),
            chunk_id: integer()
          }

    defstruct [
      :file_url,
      :file_id,
      :checksum,
      :total_size,
      :file_name,
      :finished,
      :client_file_id,
      :chunk_id,
      file_type: :video
    ]

    @spec from_response(map(), map(), String.t()) :: t()
    def from_response(response, file_data, checksum) do
      %__MODULE__{
        file_type: :video,
        file_url: response["fileUrl"],
        file_id: response["fileId"],
        checksum: checksum,
        total_size: file_data[:total_size] || file_data["totalSize"],
        file_name: file_data[:file_name] || file_data["fileName"],
        finished: normalize_finished(response["finished"]),
        client_file_id: response["clientFileId"],
        chunk_id: response["chunkId"]
      }
    end

    defp normalize_finished(1), do: true
    defp normalize_finished(0), do: false
    defp normalize_finished(true), do: true
    defp normalize_finished(false), do: false
    defp normalize_finished(_), do: false
  end

  defmodule FileResponse do
    @moduledoc "Response for an uploaded file (non-image, non-video)"

    @type t :: %__MODULE__{
            file_type: :file,
            file_url: String.t() | nil,
            file_id: String.t(),
            checksum: String.t(),
            total_size: non_neg_integer(),
            file_name: String.t(),
            finished: boolean(),
            client_file_id: integer(),
            chunk_id: integer()
          }

    defstruct [
      :file_url,
      :file_id,
      :checksum,
      :total_size,
      :file_name,
      :finished,
      :client_file_id,
      :chunk_id,
      file_type: :file
    ]

    @spec from_response(map(), map(), String.t()) :: t()
    def from_response(response, file_data, checksum) do
      %__MODULE__{
        file_type: :file,
        file_url: response["fileUrl"],
        file_id: response["fileId"],
        checksum: checksum,
        total_size: file_data[:total_size] || file_data["totalSize"],
        file_name: file_data[:file_name] || file_data["fileName"],
        finished: normalize_finished(response["finished"]),
        client_file_id: response["clientFileId"],
        chunk_id: response["chunkId"]
      }
    end

    defp normalize_finished(1), do: true
    defp normalize_finished(0), do: false
    defp normalize_finished(true), do: true
    defp normalize_finished(false), do: false
    defp normalize_finished(_), do: false
  end

  @type file_type :: :image | :video | :file
  @type upload_response :: ImageResponse.t() | VideoResponse.t() | FileResponse.t()

  @image_extensions ~w(jpg jpeg png webp)
  @video_extensions ~w(mp4)

  @doc """
  Determine file type from extension.

  Returns `:image` for jpg/jpeg/png/webp, `:video` for mp4, `:file` for others.
  """
  @spec detect_file_type(String.t()) :: file_type()
  def detect_file_type(filename) when is_binary(filename) do
    ext =
      filename
      |> Path.extname()
      |> String.trim_leading(".")
      |> String.downcase()

    cond do
      ext in @image_extensions -> :image
      ext in @video_extensions -> :video
      true -> :file
    end
  end

  @doc "Get file extension (lowercase, without dot)"
  @spec get_extension(String.t()) :: String.t()
  def get_extension(filename) when is_binary(filename) do
    filename
    |> Path.extname()
    |> String.trim_leading(".")
    |> String.downcase()
  end

  @doc "Get URL path suffix for file type"
  @spec url_path_for_type(file_type()) :: String.t()
  def url_path_for_type(:image), do: "photo_original/upload"
  def url_path_for_type(:video), do: "asyncfile/upload"
  def url_path_for_type(:file), do: "asyncfile/upload"
end
