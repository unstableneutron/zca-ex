defmodule ZcaEx.Error do
  @moduledoc "Error struct for Zalo API errors"

  @type t :: %__MODULE__{
          message: String.t(),
          code: integer() | nil
        }

  defexception [:message, :code]

  @impl true
  def message(%{message: msg, code: nil}), do: msg
  def message(%{message: msg, code: code}), do: "[#{code}] #{msg}"
end
