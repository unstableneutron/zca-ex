defmodule ZcaEx.Api.Endpoints.ChangeAccountAvatar do
  @moduledoc "Change account avatar"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type avatar_metadata :: %{
          width: non_neg_integer(),
          height: non_neg_integer(),
          size: non_neg_integer()
        }

  @doc """
  Change account avatar.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - image_data: Binary image data
    - opts: Options
      - `:width` - Image width (default: 1080)
      - `:height` - Image height (default: 1080)
      - `:size` - File size in bytes (default: byte_size(image_data))

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), binary(), keyword()) ::
          {:ok, :success} | {:error, Error.t()}
  def call(session, credentials, image_data, opts \\ []) do
    with :ok <- validate_image_data(image_data) do
      width = Keyword.get(opts, :width, 1080)
      height = Keyword.get(opts, :height, 1080)
      size = Keyword.get(opts, :size, byte_size(image_data))

      params = build_params(session.uid, width, height, size, credentials.language)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(session, encrypted_params)
          parts = [{"fileContent", image_data, filename: "blob", content_type: "image/jpeg"}]

          case AccountClient.post_multipart(session.uid, url, parts, credentials.user_agent) do
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

  @doc "Validate image data"
  @spec validate_image_data(term()) :: :ok | {:error, Error.t()}
  def validate_image_data(data) when is_binary(data) and byte_size(data) > 0, do: :ok
  def validate_image_data(nil), do: {:error, %Error{message: "Image data is required", code: nil}}
  def validate_image_data(<<>>), do: {:error, %Error{message: "Image data cannot be empty", code: nil}}

  def validate_image_data(_),
    do: {:error, %Error{message: "Image data must be a binary", code: nil}}

  @doc "Build URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :file) <> "/api/profile/upavatar"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :file) <> "/api/profile/upavatar"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), String.t()) ::
          map()
  def build_params(uid, width, height, size, language) do
    formatted_time = format_timestamp(System.system_time(:millisecond))
    client_id = "#{uid}#{formatted_time}"

    metadata = %{
      origin: %{width: width, height: height},
      processed: %{width: width, height: height, size: size}
    }

    {:ok, metadata_json} = Jason.encode(metadata)

    %{
      avatarSize: 120,
      clientId: client_id,
      language: language,
      metaData: metadata_json
    }
  end

  @doc "Format timestamp in the expected format: HH:MM DD/MM/YYYY"
  @spec format_timestamp(integer()) :: String.t()
  def format_timestamp(milliseconds) do
    datetime = DateTime.from_unix!(div(milliseconds, 1000))

    hours = datetime.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes = datetime.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    day = datetime.day |> Integer.to_string() |> String.pad_leading(2, "0")
    month = datetime.month |> Integer.to_string() |> String.pad_leading(2, "0")
    year = datetime.year

    "#{hours}:#{minutes} #{day}/#{month}/#{year}"
  end

  @doc "Build client ID from uid and timestamp"
  @spec build_client_id(String.t(), integer()) :: String.t()
  def build_client_id(uid, timestamp_ms) do
    "#{uid}#{format_timestamp(timestamp_ms)}"
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
