defmodule ZcaEx.Api.Endpoints.SendVideo do
  @moduledoc """
  Send video messages via URL.

  ## Example

      SendVideo.send(
        %{video_url: "https://example.com/video.mp4", thumbnail_url: "https://example.com/thumb.jpg"},
        "user_id",
        :user,
        session,
        creds
      )
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type options :: %{
          required(:video_url) => String.t(),
          required(:thumbnail_url) => String.t(),
          optional(:msg) => String.t(),
          optional(:duration) => integer(),
          optional(:width) => integer(),
          optional(:height) => integer(),
          optional(:ttl) => integer()
        }

  @spec send(options(), String.t(), :user | :group, Session.t(), Credentials.t()) ::
          {:ok, %{msg_id: integer()}} | {:error, Error.t()}
  def send(options, thread_id, thread_type, session, credentials) do
    with :ok <- validate_options(options),
         :ok <- validate_thread_id(thread_id),
         :ok <- validate_thread_type(thread_type),
         {:ok, file_size} <- fetch_file_size(options.video_url) do
      url = build_url(session, thread_type)
      params = build_params(options, thread_id, thread_type, file_size, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
            {:ok, response} ->
              Response.parse(response, session.secret_key)
              |> extract_msg_id()

            {:error, reason} ->
              {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "Build the forward URL based on thread type"
  @spec build_url(Session.t(), :user | :group) :: String.t()
  def build_url(session, thread_type) do
    base = get_base_url(session, thread_type)
    Url.build(base, %{}, nretry: 0, api_type: session.api_type, version: session.api_version)
  end

  @doc false
  def get_base_url(session, :user) do
    get_in(session.zpw_service_map, ["file", Access.at(0)]) <> "/api/message/forward"
  end

  def get_base_url(session, :group) do
    get_in(session.zpw_service_map, ["file", Access.at(0)]) <> "/api/group/forward"
  end

  @doc "Build API params from options"
  @spec build_params(options(), String.t(), :user | :group, integer(), Credentials.t()) :: map()
  def build_params(options, thread_id, thread_type, file_size, creds) do
    is_group = thread_type == :group
    client_id = System.system_time(:millisecond)

    msg_info = %{
      videoUrl: options.video_url,
      thumbUrl: options.thumbnail_url,
      duration: options[:duration] || 0,
      width: options[:width] || 1280,
      height: options[:height] || 720,
      fileSize: file_size,
      properties: %{
        color: -1,
        size: -1,
        type: 1003,
        subType: 0,
        ext: %{
          sSrcType: -1,
          sSrcStr: "",
          msg_warning_type: 0
        }
      },
      title: options[:msg] || ""
    }

    base = %{
      clientId: to_string(client_id),
      ttl: options[:ttl] || 0,
      zsource: 704,
      msgType: 5,
      msgInfo: Jason.encode!(msg_info),
      imei: creds.imei
    }

    if is_group do
      base
      |> Map.put(:grid, thread_id)
      |> Map.put(:visibility, 0)
    else
      Map.put(base, :toId, thread_id)
    end
  end

  @doc "Fetch file size via HEAD request"
  @spec fetch_file_size(String.t()) :: {:ok, integer()} | {:error, Error.t()}
  def fetch_file_size(url) do
    case Req.head(url) do
      {:ok, %{status: status, headers: headers}} when status in 200..299 ->
        content_length =
          headers
          |> Enum.find_value(0, fn
            {"content-length", val} -> String.to_integer(val)
            _ -> nil
          end)

        {:ok, content_length || 0}

      {:ok, %{status: _status}} ->
        {:ok, 0}

      {:error, reason} ->
        {:error, %Error{message: "Unable to get video content: #{inspect(reason)}", code: nil}}
    end
  end

  defp validate_options(%{video_url: url, thumbnail_url: thumb})
       when is_binary(url) and byte_size(url) > 0 and is_binary(thumb) and byte_size(thumb) > 0 do
    :ok
  end

  defp validate_options(_) do
    {:error, %Error{message: "Missing video_url or thumbnail_url", code: nil}}
  end

  defp validate_thread_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  defp validate_thread_id(_), do: {:error, %Error{message: "Missing threadId", code: nil}}

  defp validate_thread_type(type) when type in [:user, :group], do: :ok
  defp validate_thread_type(_), do: {:error, %Error{message: "Thread type is invalid", code: nil}}

  defp extract_msg_id({:ok, %{"msgId" => msg_id}}), do: {:ok, %{msg_id: msg_id}}
  defp extract_msg_id({:ok, data}) when is_map(data), do: {:ok, data}
  defp extract_msg_id({:error, _} = error), do: error
end
