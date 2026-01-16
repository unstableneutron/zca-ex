defmodule ZcaEx.Model.ReminderRepeatMode do
  @moduledoc "Reminder repeat mode constants for Zalo API"

  @none 0
  @daily 1
  @weekly 2
  @monthly 3

  @doc "No repeat"
  def none, do: @none

  @doc "Repeat daily"
  def daily, do: @daily

  @doc "Repeat weekly"
  def weekly, do: @weekly

  @doc "Repeat monthly"
  def monthly, do: @monthly

  @doc "Convert atom or integer to repeat mode value"
  @spec to_value(:none | :daily | :weekly | :monthly | integer()) :: integer()
  def to_value(:none), do: @none
  def to_value(:daily), do: @daily
  def to_value(:weekly), do: @weekly
  def to_value(:monthly), do: @monthly
  def to_value(v) when is_integer(v), do: v
end
