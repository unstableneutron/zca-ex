defmodule ZcaEx.WS.Frame do
  @moduledoc """
  WebSocket binary frame encoding/decoding for Zalo protocol.

  Binary frame format: 4-byte header + JSON payload
  - byte 0: version (1 byte)
  - bytes 1-2: cmd (2 bytes, little-endian uint16)
  - byte 3: subCmd (1 byte)
  - remaining: JSON UTF-8 string
  """

  @type header :: {version :: non_neg_integer(), cmd :: non_neg_integer(), sub_cmd :: non_neg_integer()}
  @type payload :: map()

  @header_size 4

  @doc """
  Decodes a binary WebSocket frame into header and payload.

  Returns `{:ok, {version, cmd, sub_cmd}, data}` or `{:error, reason}`.
  """
  @spec decode(binary()) :: {:ok, header(), payload()} | {:error, term()}
  def decode(<<version::8, cmd::16-little, sub_cmd::8, rest::binary>>) do
    case rest do
      <<>> ->
        {:ok, {version, cmd, sub_cmd}, %{}}

      json_data ->
        case Jason.decode(json_data) do
          {:ok, data} -> {:ok, {version, cmd, sub_cmd}, data}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end
    end
  end

  def decode(binary) when is_binary(binary) and byte_size(binary) < @header_size do
    {:error, :invalid_frame_too_short}
  end

  def decode(_), do: {:error, :invalid_frame}

  @doc """
  Encodes a frame with the given header values and payload.

  Returns the binary frame.
  """
  @spec encode(non_neg_integer(), non_neg_integer(), non_neg_integer(), payload()) :: binary()
  def encode(version, cmd, sub_cmd, data) when is_map(data) do
    header = <<version::8, cmd::16-little, sub_cmd::8>>
    json_payload = Jason.encode!(data)
    header <> json_payload
  end

  @doc """
  Builds a ping frame.

  Uses version=1, cmd=2, subCmd=1, with data containing the current timestamp.
  """
  @spec ping_frame() :: binary()
  def ping_frame do
    encode(1, 2, 1, %{"eventId" => System.system_time(:millisecond)})
  end

  @doc """
  Builds a request frame for fetching old messages.

  - thread_type :user -> cmd=510
  - thread_type :group -> cmd=511
  - subCmd=1
  """
  @spec old_messages_frame(:user | :group, String.t() | integer()) :: binary()
  def old_messages_frame(thread_type, last_id) do
    cmd = thread_type_to_messages_cmd(thread_type)
    data = %{"first" => true, "lastId" => last_id, "preIds" => []}
    encode(1, cmd, 1, data)
  end

  @doc """
  Builds a request frame for fetching old reactions.

  - thread_type :user -> cmd=610
  - thread_type :group -> cmd=611
  - subCmd=1
  """
  @spec old_reactions_frame(:user | :group, String.t() | integer()) :: binary()
  def old_reactions_frame(thread_type, last_id) do
    cmd = thread_type_to_reactions_cmd(thread_type)
    data = %{"first" => true, "lastId" => last_id, "preIds" => []}
    encode(1, cmd, 1, data)
  end

  defp thread_type_to_messages_cmd(:user), do: 510
  defp thread_type_to_messages_cmd(:group), do: 511

  defp thread_type_to_reactions_cmd(:user), do: 610
  defp thread_type_to_reactions_cmd(:group), do: 611
end
