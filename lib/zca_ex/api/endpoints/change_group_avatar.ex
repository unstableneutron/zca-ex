defmodule ZcaEx.Api.Endpoints.ChangeGroupAvatar do
  @moduledoc """
  Change group avatar endpoint.

  Uploads a new avatar image for a group.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @default_width 1080
  @default_height 1080
  @avatar_size 120

  @doc """
  Change group avatar.

  ## Parameters
    - image_data: Binary image data
    - group_id: Group ID
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Optional keyword list with `:width` and `:height` (default: 1080x1080)

  ## Returns
    - `{:ok, %{}}` on success (empty response)
    - `{:error, Error.t()}` on failure
  """
  @spec call(binary(), String.t(), Session.t(), Credentials.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(image_data, group_id, session, credentials, opts \\ []) do
    width = Keyword.get(opts, :width, @default_width)
    height = Keyword.get(opts, :height, @default_height)

    with :ok <- validate_image_data(image_data),
         :ok <- validate_group_id(group_id),
         {:ok, encrypted_params} <-
           encrypt_params(session.secret_key, build_params(group_id, credentials, width, height)) do
      url = build_url(session, encrypted_params)
      parts = build_multipart_parts(image_data)

      case AccountClient.post_multipart(session.uid, url, parts, credentials.user_agent) do
        {:ok, response} ->
          Response.parse(response, session.secret_key)

        {:error, reason} ->
          {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
      end
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), Credentials.t(), integer(), integer()) :: map()
  def build_params(group_id, credentials, width \\ @default_width, height \\ @default_height) do
    %{
      grid: group_id,
      avatarSize: @avatar_size,
      clientId: build_client_id(group_id),
      imei: credentials.imei,
      originWidth: width,
      originHeight: height
    }
  end

  @doc "Build URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :file) <> "/api/group/upavatar"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc """
  Build client ID in format: "g" <> group_id <> timestamp_string

  Timestamp format: "HH:MM DD/MM/YYYY"
  """
  @spec build_client_id(String.t()) :: String.t()
  def build_client_id(group_id) do
    "g" <> group_id <> format_timestamp(System.system_time(:millisecond))
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

  defp build_multipart_parts(image_data) do
    [{"fileContent", image_data, filename: "blob", content_type: "image/jpeg"}]
  end

  defp validate_image_data(nil), do: {:error, %Error{message: "Missing image_data", code: nil}}
  defp validate_image_data(<<>>), do: {:error, %Error{message: "Empty image_data", code: nil}}
  defp validate_image_data(data) when is_binary(data), do: :ok
  defp validate_image_data(_), do: {:error, %Error{message: "Invalid image_data", code: nil}}

  defp validate_group_id(nil), do: {:error, %Error{message: "Missing group_id", code: nil}}
  defp validate_group_id(""), do: {:error, %Error{message: "Missing group_id", code: nil}}
  defp validate_group_id(id) when is_binary(id), do: :ok
  defp validate_group_id(_), do: {:error, %Error{message: "Invalid group_id", code: nil}}

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
