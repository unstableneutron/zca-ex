defmodule ZcaEx.Model.SeenMessage do
  @moduledoc "Seen/read receipt event struct"

  alias ZcaEx.Model.Enums

  @type t :: %__MODULE__{
          msg_id: String.t(),
          real_msg_id: String.t() | nil,
          id_to: String.t() | nil,
          group_id: String.t() | nil,
          thread_id: String.t(),
          thread_type: Enums.thread_type(),
          is_self: boolean(),
          seen_uids: [String.t()] | nil
        }

  defstruct [
    :msg_id,
    :real_msg_id,
    :id_to,
    :group_id,
    :thread_id,
    :thread_type,
    :is_self,
    :seen_uids
  ]

  @doc "Create seen message from raw WebSocket data"
  @spec from_ws_data(data :: map(), uid :: String.t(), thread_type :: Enums.thread_type()) :: t()
  def from_ws_data(data, _uid, :user) do
    %__MODULE__{
      msg_id: data["msgId"],
      real_msg_id: data["realMsgId"],
      id_to: data["idTo"],
      group_id: nil,
      thread_id: data["idTo"],
      thread_type: :user,
      is_self: false,
      seen_uids: nil
    }
  end

  def from_ws_data(data, uid, :group) do
    seen_uids = data["seenUids"] || []
    is_self = uid in seen_uids

    %__MODULE__{
      msg_id: data["msgId"],
      real_msg_id: nil,
      id_to: nil,
      group_id: data["groupId"],
      thread_id: data["groupId"],
      thread_type: :group,
      is_self: is_self,
      seen_uids: seen_uids
    }
  end
end
