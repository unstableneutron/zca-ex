defmodule ZcaEx.Model.Mention do
  @moduledoc "Mention struct for message mentions"

  @type t :: %__MODULE__{
          uid: String.t(),
          pos: non_neg_integer(),
          len: non_neg_integer(),
          type: 0 | 1
        }

  defstruct [:uid, :pos, :len, :type]

  @doc "Create a normal mention (type 0)"
  @spec new(uid :: String.t(), pos :: non_neg_integer(), len :: non_neg_integer()) :: t()
  def new(uid, pos, len) do
    %__MODULE__{uid: uid, pos: pos, len: len, type: 0}
  end

  @doc "Create an @all mention (type 1)"
  @spec new_all(pos :: non_neg_integer(), len :: non_neg_integer()) :: t()
  def new_all(pos, len) do
    %__MODULE__{uid: "-1", pos: pos, len: len, type: 1}
  end

  @doc "Create from raw map data"
  @spec from_map(map()) :: t()
  def from_map(%{"uid" => uid, "pos" => pos, "len" => len, "type" => type}) do
    %__MODULE__{
      uid: to_string(uid),
      pos: pos,
      len: len,
      type: type
    }
  end

  def from_map(%{"uid" => uid, "pos" => pos, "len" => len}) do
    %__MODULE__{
      uid: to_string(uid),
      pos: pos,
      len: len,
      type: 0
    }
  end

  @doc "Convert to API format"
  @spec to_api_format(t()) :: map()
  def to_api_format(%__MODULE__{uid: uid, pos: pos, len: len, type: type}) do
    %{"uid" => uid, "pos" => pos, "len" => len, "type" => type}
  end
end
