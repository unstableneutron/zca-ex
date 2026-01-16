defmodule ZcaEx.Model.Urgency do
  @moduledoc "Urgency enum for message priority"

  @type t :: :default | :important | :urgent

  @doc "Convert urgency to API integer value"
  @spec to_api_value(t()) :: 0 | 1 | 2
  def to_api_value(:default), do: 0
  def to_api_value(:important), do: 1
  def to_api_value(:urgent), do: 2

  @doc "Parse API integer value to urgency"
  @spec from_api_value(integer()) :: t()
  def from_api_value(0), do: :default
  def from_api_value(1), do: :important
  def from_api_value(2), do: :urgent
end
