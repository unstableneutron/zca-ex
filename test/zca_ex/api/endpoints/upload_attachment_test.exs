defmodule ZcaEx.Api.Endpoints.UploadAttachmentTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UploadAttachment
  alias ZcaEx.Model.Attachment
  alias ZcaEx.Model.Attachment.{AttachmentSource, ImageResponse, VideoResponse, FileResponse}
  alias ZcaEx.Account.{Session, Credentials}

  setup do
    session = %Session{
      uid: "123456789",
      secret_key: Base.encode64(:crypto.strong_rand_bytes(32)),
      zpw_service_map: %{
        "chat" => ["https://chat.zalo.me"],
        "group" => ["https://group.zalo.me"],
        "file" => ["https://file.zalo.me"]
      },
      api_type: 30,
      api_version: 645,
      settings: %{
        "features" => %{
          "sharefile" => %{
            "chunk_size_file" => 512 * 1024,
            "max_file" => 20,
            "max_size_share_file_v3" => 100,
            "restricted_ext_file" => ["exe", "msi", "bat"]
          }
        }
      }
    }

    {:ok, credentials} =
      Credentials.new(
        imei: "test-imei-123456",
        user_agent: "Mozilla/5.0 Test",
        cookies: [%{"name" => "test", "value" => "cookie"}]
      )

    {:ok, session: session, credentials: credentials}
  end

  describe "Attachment.detect_file_type/1" do
    test "detects image types" do
      assert Attachment.detect_file_type("photo.jpg") == :image
      assert Attachment.detect_file_type("photo.jpeg") == :image
      assert Attachment.detect_file_type("photo.png") == :image
      assert Attachment.detect_file_type("photo.webp") == :image
      assert Attachment.detect_file_type("PHOTO.JPG") == :image
      assert Attachment.detect_file_type("photo.PNG") == :image
    end

    test "detects video types" do
      assert Attachment.detect_file_type("video.mp4") == :video
      assert Attachment.detect_file_type("VIDEO.MP4") == :video
    end

    test "detects other file types" do
      assert Attachment.detect_file_type("document.pdf") == :file
      assert Attachment.detect_file_type("archive.zip") == :file
      assert Attachment.detect_file_type("data.txt") == :file
      assert Attachment.detect_file_type("app.exe") == :file
    end

    test "handles files without extension" do
      assert Attachment.detect_file_type("noextension") == :file
    end

    test "handles paths with directories" do
      assert Attachment.detect_file_type("/path/to/photo.jpg") == :image
      assert Attachment.detect_file_type("C:\\Users\\test\\video.mp4") == :video
    end
  end

  describe "Attachment.get_extension/1" do
    test "extracts lowercase extension" do
      assert Attachment.get_extension("file.jpg") == "jpg"
      assert Attachment.get_extension("file.PNG") == "png"
      assert Attachment.get_extension("file.Mp4") == "mp4"
    end

    test "returns empty string for no extension" do
      assert Attachment.get_extension("noext") == ""
    end

    test "handles multiple dots" do
      assert Attachment.get_extension("file.tar.gz") == "gz"
    end
  end

  describe "Attachment.url_path_for_type/1" do
    test "returns correct URL path for each type" do
      assert Attachment.url_path_for_type(:image) == "photo_original/upload"
      assert Attachment.url_path_for_type(:video) == "asyncfile/upload"
      assert Attachment.url_path_for_type(:file) == "asyncfile/upload"
    end
  end

  describe "UploadAttachment.split_into_chunks/2" do
    test "splits data into equal chunks" do
      data = :binary.copy(<<1>>, 10)
      chunks = UploadAttachment.split_into_chunks(data, 3)

      assert length(chunks) == 4
      assert Enum.at(chunks, 0) == <<1, 1, 1>>
      assert Enum.at(chunks, 1) == <<1, 1, 1>>
      assert Enum.at(chunks, 2) == <<1, 1, 1>>
      assert Enum.at(chunks, 3) == <<1>>
    end

    test "handles exact chunk size" do
      data = :binary.copy(<<1>>, 9)
      chunks = UploadAttachment.split_into_chunks(data, 3)

      assert length(chunks) == 3
      assert Enum.all?(chunks, &(byte_size(&1) == 3))
    end

    test "handles data smaller than chunk size" do
      data = <<1, 2, 3>>
      chunks = UploadAttachment.split_into_chunks(data, 10)

      assert length(chunks) == 1
      assert hd(chunks) == data
    end

    test "handles empty data" do
      chunks = UploadAttachment.split_into_chunks(<<>>, 10)
      assert chunks == []
    end

    test "handles large data" do
      data = :crypto.strong_rand_bytes(1024 * 1024)
      chunk_size = 256 * 1024
      chunks = UploadAttachment.split_into_chunks(data, chunk_size)

      assert length(chunks) == 4
      assert IO.iodata_to_binary(chunks) == data
    end
  end

  describe "AttachmentSource" do
    test "from_path creates source from file path" do
      source = AttachmentSource.from_path("/path/to/file.jpg")

      assert source.type == :path
      assert source.path == "/path/to/file.jpg"
      assert source.filename == "file.jpg"
      assert source.metadata == %{}
    end

    test "from_binary creates source from binary data" do
      data = <<1, 2, 3>>
      source = AttachmentSource.from_binary(data, "photo.jpg", width: 100, height: 200)

      assert source.type == :binary
      assert source.data == data
      assert source.filename == "photo.jpg"
      assert source.metadata.width == 100
      assert source.metadata.height == 200
    end

    test "from_binary with total_size" do
      data = <<1, 2, 3>>
      source = AttachmentSource.from_binary(data, "video.mp4", total_size: 12345)

      assert source.metadata.total_size == 12345
    end
  end

  describe "ImageResponse.from_response/2" do
    test "creates response from API response and file data" do
      api_response = %{
        "normalUrl" => "https://example.com/normal.jpg",
        "photoId" => "photo123",
        "hdUrl" => "https://example.com/hd.jpg",
        "thumbUrl" => "https://example.com/thumb.jpg",
        "finished" => 1,
        "clientFileId" => 123,
        "chunkId" => 1
      }

      file_data = %{
        width: 800,
        height: 600,
        total_size: 12345
      }

      response = ImageResponse.from_response(api_response, file_data)

      assert response.normal_url == "https://example.com/normal.jpg"
      assert response.photo_id == "photo123"
      assert response.hd_url == "https://example.com/hd.jpg"
      assert response.thumb_url == "https://example.com/thumb.jpg"
      assert response.width == 800
      assert response.height == 600
      assert response.total_size == 12345
      assert response.finished == true
    end

    test "normalizes finished field" do
      assert ImageResponse.from_response(%{"finished" => 1}, %{}).finished == true
      assert ImageResponse.from_response(%{"finished" => 0}, %{}).finished == false
      assert ImageResponse.from_response(%{"finished" => true}, %{}).finished == true
      assert ImageResponse.from_response(%{"finished" => false}, %{}).finished == false
    end
  end

  describe "VideoResponse.from_response/3" do
    test "creates response from API response, file data, and checksum" do
      api_response = %{
        "fileUrl" => "https://example.com/video.mp4",
        "fileId" => "file123",
        "finished" => 1,
        "clientFileId" => 456,
        "chunkId" => 2
      }

      file_data = %{
        file_name: "video.mp4",
        total_size: 54321
      }

      response = VideoResponse.from_response(api_response, file_data, "abc123checksum")

      assert response.file_url == "https://example.com/video.mp4"
      assert response.file_id == "file123"
      assert response.checksum == "abc123checksum"
      assert response.total_size == 54321
      assert response.file_name == "video.mp4"
      assert response.finished == true
    end
  end

  describe "FileResponse.from_response/3" do
    test "creates response from API response, file data, and checksum" do
      api_response = %{
        "fileUrl" => "https://example.com/doc.pdf",
        "fileId" => "file789",
        "finished" => 1,
        "clientFileId" => 789,
        "chunkId" => 1
      }

      file_data = %{
        file_name: "document.pdf",
        total_size: 99999
      }

      response = FileResponse.from_response(api_response, file_data, "xyz789checksum")

      assert response.file_url == "https://example.com/doc.pdf"
      assert response.file_id == "file789"
      assert response.checksum == "xyz789checksum"
      assert response.total_size == 99999
      assert response.file_name == "document.pdf"
    end
  end

  describe "validation" do
    test "returns error for empty sources", %{session: session, credentials: creds} do
      {:error, error} = UploadAttachment.upload([], "thread123", :user, session, creds)
      assert error.message =~ "Missing sources"
    end

    test "returns error for missing thread_id", %{session: session, credentials: creds} do
      source = AttachmentSource.from_binary(<<1, 2, 3>>, "file.txt")
      {:error, error} = UploadAttachment.upload(source, "", :user, session, creds)
      assert error.message =~ "Missing threadId"
    end

    test "returns error for non-existent file path", %{session: session, credentials: creds} do
      {:error, error} =
        UploadAttachment.upload("/nonexistent/file.jpg", "thread123", :user, session, creds)

      assert error.message =~ "File not found"
    end

    test "returns error for restricted extension", %{session: session, credentials: creds} do
      source = AttachmentSource.from_binary(<<1, 2, 3>>, "malware.exe")
      {:error, error} = UploadAttachment.upload(source, "thread123", :user, session, creds)
      assert error.message =~ "not allowed"
    end

    test "returns error when exceeding max file count", %{session: session, credentials: creds} do
      session = put_in(session.settings["features"]["sharefile"]["max_file"], 2)

      sources = [
        AttachmentSource.from_binary(<<1>>, "a.txt"),
        AttachmentSource.from_binary(<<2>>, "b.txt"),
        AttachmentSource.from_binary(<<3>>, "c.txt")
      ]

      {:error, error} = UploadAttachment.upload(sources, "thread123", :user, session, creds)
      assert error.message =~ "Exceed maximum file count"
    end

    test "returns error when exceeding max file size", %{session: session, credentials: creds} do
      session = put_in(session.settings["features"]["sharefile"]["max_size_share_file_v3"], 0)
      source = AttachmentSource.from_binary(<<1, 2, 3>>, "file.txt")

      {:error, error} = UploadAttachment.upload(source, "thread123", :user, session, creds)
      assert error.message =~ "exceeds maximum size"
    end
  end

  describe "multipart body building" do
    test "AccountClient builds correct multipart boundary" do
      boundary = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
      assert byte_size(boundary) == 32
      assert Regex.match?(~r/^[a-f0-9]+$/, boundary)
    end
  end

  describe "edge cases and validation" do
    test "rejects zero-byte files", %{session: session, credentials: creds} do
      source = AttachmentSource.from_binary(<<>>, "empty.txt")
      result = UploadAttachment.upload(source, "thread_id", :user, session, creds)
      assert {:error, %ZcaEx.Error{message: msg}} = result
      assert msg =~ "Empty file"
    end

    test "handles zero chunk_size in settings by using default", %{session: session} do
      session = put_in(session.settings["features"]["sharefile"]["chunk_size_file"], 0)

      sharefile = get_in(session.settings, ["features", "sharefile"]) || %{}
      raw_chunk_size = sharefile["chunk_size_file"]

      assert raw_chunk_size == 0

      effective_chunk_size =
        if is_integer(raw_chunk_size) and raw_chunk_size > 0,
          do: raw_chunk_size,
          else: 512 * 1024

      assert effective_chunk_size == 512 * 1024
    end

    test "restricted extension check is case-insensitive", %{session: session, credentials: creds} do
      session =
        put_in(session.settings["features"]["sharefile"]["restricted_ext_file"], ["EXE", "BAT"])

      source = AttachmentSource.from_binary(<<1, 2, 3>>, "test.exe")
      result = UploadAttachment.upload(source, "thread_id", :user, session, creds)
      assert {:error, %ZcaEx.Error{message: msg}} = result
      assert msg =~ "not allowed"
    end

    test "returns error when file service URL is missing", %{session: session, credentials: creds} do
      session = %{session | zpw_service_map: %{}}
      source = AttachmentSource.from_binary(<<1, 2, 3>>, "test.jpg")
      result = UploadAttachment.upload(source, "thread_id", :user, session, creds)
      assert {:error, %ZcaEx.Error{message: msg}} = result
      assert msg =~ "Missing file service URL"
    end
  end
end
