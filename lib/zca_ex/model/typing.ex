defmodule ZcaEx.Model.Typing do
  @moduledoc "Typing indicator event struct for user and group typing events"

  alias ZcaEx.Model.Enums

  @type t :: %__MODULE__{
          uid: String.t(),
          ts: String.t(),
          is_pc: boolean(),
          thread_id: String.t(),
          thread_type: Enums.thread_type(),
          is_self: boolean()
        }

  defstruct [:uid, :ts, :is_pc, :thread_id, :thread_type, :is_self]

  @doc """
  Create typing event from raw WebSocket data.

  The `act` field determines thread type:
  - "typing" -> user typing (thread_id = uid)
  - "gtyping" -> group typing (thread_id = gid)

  Note: Typing indicators never come from self, so is_self is always false.
  """
  @spec from_ws_data(data :: map(), act :: String.t()) :: t()
  def from_ws_data(data, act) do
    thread_type = get_thread_type(act)
    thread_id = get_thread_id(data, thread_type)

    %__MODULE__{
      uid: data["uid"],
      ts: data["ts"],
      is_pc: data["isPC"] == 1,
      thread_id: thread_id,
      thread_type: thread_type,
      is_self: false
    }
  end

  defp get_thread_type("gtyping"), do: :group
  defp get_thread_type(_), do: :user

  defp get_thread_id(%{"gid" => gid}, :group), do: gid
  defp get_thread_id(%{"uid" => uid}, :user), do: uid
end
