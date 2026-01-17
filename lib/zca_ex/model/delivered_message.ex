defmodule ZcaEx.Model.DeliveredMessage do
  @moduledoc "Delivery receipt event struct"

  alias ZcaEx.Model.Enums

  @type t :: %__MODULE__{
          msg_id: String.t(),
          real_msg_id: String.t() | nil,
          group_id: String.t() | nil,
          thread_id: String.t(),
          thread_type: Enums.thread_type(),
          is_self: boolean(),
          seen: integer(),
          delivered_uids: [String.t()],
          seen_uids: [String.t()],
          ts: integer() | nil
        }

  defstruct [
    :msg_id,
    :real_msg_id,
    :group_id,
    :thread_id,
    :thread_type,
    :is_self,
    :seen,
    :delivered_uids,
    :seen_uids,
    :ts
  ]

  @doc "Create delivered message from raw WebSocket data"
  @spec from_ws_data(data :: map(), uid :: String.t(), thread_type :: Enums.thread_type()) :: t()
  def from_ws_data(data, _uid, :user) do
    delivered_uids = data["deliveredUids"] || []

    %__MODULE__{
      msg_id: data["msgId"],
      real_msg_id: data["realMsgId"],
      group_id: nil,
      thread_id: List.first(delivered_uids) || "",
      thread_type: :user,
      is_self: false,
      seen: data["seen"] || 0,
      delivered_uids: delivered_uids,
      seen_uids: data["seenUids"] || [],
      ts: data["mSTs"]
    }
  end

  def from_ws_data(data, uid, :group) do
    delivered_uids = data["deliveredUids"] || []
    is_self = uid in delivered_uids

    %__MODULE__{
      msg_id: data["msgId"],
      real_msg_id: data["realMsgId"],
      group_id: data["groupId"],
      thread_id: data["groupId"],
      thread_type: :group,
      is_self: is_self,
      seen: data["seen"] || 0,
      delivered_uids: delivered_uids,
      seen_uids: data["seenUids"] || [],
      ts: data["mSTs"]
    }
  end
end
