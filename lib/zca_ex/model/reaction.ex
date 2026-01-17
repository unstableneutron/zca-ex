defmodule ZcaEx.Model.Reaction do
  @moduledoc "Reaction event struct for message reactions"

  alias ZcaEx.Model.Enums

  @type t :: %__MODULE__{
          action_id: String.t(),
          msg_id: String.t(),
          cli_msg_id: String.t(),
          msg_type: String.t(),
          uid_from: String.t(),
          id_to: String.t(),
          d_name: String.t() | nil,
          content: map(),
          ts: String.t(),
          ttl: integer(),
          thread_id: String.t(),
          thread_type: Enums.thread_type(),
          is_self: boolean()
        }

  defstruct [
    :action_id,
    :msg_id,
    :cli_msg_id,
    :msg_type,
    :uid_from,
    :id_to,
    :d_name,
    :content,
    :ts,
    :ttl,
    :thread_id,
    :thread_type,
    :is_self
  ]

  @doc "Create reaction from raw WebSocket data"
  @spec from_ws_data(data :: map(), uid :: String.t(), thread_type :: Enums.thread_type()) :: t()
  def from_ws_data(data, uid, thread_type) do
    is_self = data["uidFrom"] == "0"
    uid_from = get_uid_from(data, uid)
    id_to = get_id_to(data, uid)
    thread_id = get_thread_id(data, thread_type)
    content = parse_content(data["content"])

    %__MODULE__{
      action_id: data["actionId"],
      msg_id: data["msgId"],
      cli_msg_id: data["cliMsgId"],
      msg_type: data["msgType"],
      uid_from: uid_from,
      id_to: id_to,
      d_name: data["dName"],
      content: content,
      ts: data["ts"],
      ttl: data["ttl"] || 0,
      thread_id: thread_id,
      thread_type: thread_type,
      is_self: is_self
    }
  end

  defp get_uid_from(%{"uidFrom" => "0"}, uid), do: uid
  defp get_uid_from(%{"uidFrom" => uid_from}, _uid), do: uid_from

  defp get_id_to(%{"idTo" => "0"}, uid), do: uid
  defp get_id_to(%{"idTo" => id_to}, _uid), do: id_to

  # For groups or self-sent: thread_id is idTo
  defp get_thread_id(%{"uidFrom" => "0", "idTo" => id_to}, :user), do: id_to
  defp get_thread_id(%{"uidFrom" => uid_from}, :user), do: uid_from
  defp get_thread_id(%{"idTo" => id_to}, :group), do: id_to

  # Handle content that might be a JSON string or already parsed map
  defp parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{}
    end
  end

  defp parse_content(content) when is_map(content), do: content
  defp parse_content(_), do: %{}
end
