defmodule ZcaEx.Model.Message do
  @moduledoc "Message struct for Zalo messages"

  alias ZcaEx.Model.{Enums, Mention}

  @type t :: %__MODULE__{
          msg_id: String.t(),
          cli_msg_id: String.t(),
          msg_type: String.t(),
          uid_from: String.t(),
          id_to: String.t(),
          content: String.t() | map(),
          ts: String.t(),
          ttl: integer(),
          thread_id: String.t(),
          thread_type: Enums.thread_type(),
          is_self: boolean(),
          quote: map() | nil,
          mentions: [Mention.t()] | nil
        }

  defstruct [
    :msg_id,
    :cli_msg_id,
    :msg_type,
    :uid_from,
    :id_to,
    :content,
    :ts,
    :ttl,
    :thread_id,
    :thread_type,
    :is_self,
    :quote,
    :mentions
  ]

  @doc "Create message from raw WebSocket data"
  @spec from_ws_data(data :: map(), uid :: String.t(), thread_type :: Enums.thread_type()) :: t()
  def from_ws_data(data, uid, thread_type) do
    uid_from = get_uid_from(data, uid)
    id_to = get_id_to(data, uid)
    is_self = data["uidFrom"] == "0"
    thread_id = get_thread_id(data, thread_type)

    quote_data = parse_quote(data["quote"])
    mentions = parse_mentions(data["mentions"])

    %__MODULE__{
      msg_id: data["msgId"],
      cli_msg_id: data["cliMsgId"],
      msg_type: data["msgType"],
      uid_from: uid_from,
      id_to: id_to,
      content: data["content"],
      ts: data["ts"],
      ttl: data["ttl"] || 0,
      thread_id: thread_id,
      thread_type: thread_type,
      is_self: is_self,
      quote: quote_data,
      mentions: mentions
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

  defp parse_quote(nil), do: nil

  defp parse_quote(quote_data) when is_binary(quote_data) do
    case Jason.decode(quote_data) do
      {:ok, parsed} when is_map(parsed) -> Map.update(parsed, "ownerId", nil, &to_string/1)
      _ -> nil
    end
  end

  defp parse_quote(quote_data) when is_map(quote_data) do
    Map.update(quote_data, "ownerId", nil, &to_string/1)
  end

  defp parse_mentions(nil), do: nil
  defp parse_mentions([]), do: nil

  defp parse_mentions(mentions) when is_binary(mentions) do
    case Jason.decode(mentions) do
      {:ok, parsed} when is_list(parsed) -> Enum.map(parsed, &Mention.from_map/1)
      _ -> nil
    end
  end

  defp parse_mentions(mentions) when is_list(mentions) do
    Enum.map(mentions, &Mention.from_map/1)
  end
end
