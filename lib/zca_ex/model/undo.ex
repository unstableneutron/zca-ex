defmodule ZcaEx.Model.Undo do
  @moduledoc "Undo/delete message event struct"

  alias ZcaEx.Model.Enums

  @type t :: %__MODULE__{
          action_id: String.t(),
          msg_id: String.t(),
          cli_msg_id: String.t(),
          msg_type: String.t(),
          uid_from: String.t(),
          id_to: String.t(),
          d_name: String.t() | nil,
          ts: String.t(),
          status: integer(),
          content: map(),
          ttl: integer(),
          thread_id: String.t(),
          thread_type: Enums.thread_type(),
          is_self: boolean(),
          undo_msg_id: String.t() | nil
        }

  defstruct [
    :action_id,
    :msg_id,
    :cli_msg_id,
    :msg_type,
    :uid_from,
    :id_to,
    :d_name,
    :ts,
    :status,
    :content,
    :ttl,
    :thread_id,
    :thread_type,
    :is_self,
    :undo_msg_id
  ]

  @doc "Create undo event from raw WebSocket data"
  @spec from_ws_data(data :: map(), uid :: String.t(), thread_type :: Enums.thread_type()) :: t()
  def from_ws_data(data, uid, thread_type) do
    is_self = data["uidFrom"] == "0"
    uid_from = get_uid_from(data, uid)
    id_to = get_id_to(data, uid)
    thread_id = get_thread_id(data, thread_type)
    content = parse_content(data["content"])
    undo_msg_id = get_in(content, ["deleteMsg", "msgId"])

    %__MODULE__{
      action_id: data["actionId"],
      msg_id: data["msgId"],
      cli_msg_id: data["cliMsgId"],
      msg_type: data["msgType"],
      uid_from: uid_from,
      id_to: id_to,
      d_name: data["dName"],
      ts: data["ts"],
      status: data["status"] || 0,
      content: content,
      ttl: data["ttl"] || 0,
      thread_id: thread_id,
      thread_type: thread_type,
      is_self: is_self,
      undo_msg_id: undo_msg_id
    }
  end

  defp get_uid_from(%{"uidFrom" => "0"}, uid), do: uid
  defp get_uid_from(%{"uidFrom" => uid_from}, _uid) when is_binary(uid_from), do: uid_from
  defp get_uid_from(_data, uid), do: uid

  defp get_id_to(%{"idTo" => "0"}, uid), do: uid
  defp get_id_to(%{"idTo" => id_to}, _uid) when is_binary(id_to), do: id_to
  defp get_id_to(_data, uid), do: uid

  defp get_thread_id(%{"uidFrom" => "0", "idTo" => id_to}, :user), do: id_to
  defp get_thread_id(%{"uidFrom" => uid_from}, :user), do: uid_from
  defp get_thread_id(%{"idTo" => id_to}, :group), do: id_to
  defp get_thread_id(_data, _thread_type), do: nil

  defp parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{}
    end
  end

  defp parse_content(content) when is_map(content), do: content
  defp parse_content(_), do: %{}
end
