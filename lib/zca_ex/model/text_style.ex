defmodule ZcaEx.Model.TextStyle do
  @moduledoc "TextStyle struct for styled messages"

  @type style ::
          :bold
          | :italic
          | :underline
          | :strike_through
          | :red
          | :orange
          | :yellow
          | :green
          | :small
          | :big
          | :unordered_list
          | :ordered_list
          | {:indent, pos_integer()}

  @type t :: %__MODULE__{
          start: non_neg_integer(),
          len: non_neg_integer(),
          style: style()
        }

  defstruct [:start, :len, :style]

  @doc "Create a new text style"
  @spec new(start :: non_neg_integer(), len :: non_neg_integer(), style :: style()) :: t()
  def new(start, len, style) do
    %__MODULE__{start: start, len: len, style: style}
  end

  @doc "Convert style atom to Zalo API format string"
  @spec style_to_api(style()) :: String.t()
  def style_to_api(:bold), do: "b"
  def style_to_api(:italic), do: "i"
  def style_to_api(:underline), do: "u"
  def style_to_api(:strike_through), do: "s"
  def style_to_api(:red), do: "c_db342e"
  def style_to_api(:orange), do: "c_f27806"
  def style_to_api(:yellow), do: "c_f7b503"
  def style_to_api(:green), do: "c_15a85f"
  def style_to_api(:small), do: "f_13"
  def style_to_api(:big), do: "f_18"
  def style_to_api(:unordered_list), do: "lst_1"
  def style_to_api(:ordered_list), do: "lst_2"
  def style_to_api({:indent, size}) when is_integer(size) and size > 0, do: "ind_#{size}"

  @doc "Convert text style to API format map"
  @spec to_api_format(t()) :: map()
  def to_api_format(%__MODULE__{start: start, len: len, style: {:indent, size}}) do
    %{"start" => start, "len" => len, "st" => style_to_api({:indent, size}), "indentSize" => size}
  end

  def to_api_format(%__MODULE__{start: start, len: len, style: style}) do
    %{"start" => start, "len" => len, "st" => style_to_api(style)}
  end

  @doc "Parse API format string to style atom"
  @spec parse_style(String.t()) :: style()
  def parse_style("b"), do: :bold
  def parse_style("i"), do: :italic
  def parse_style("u"), do: :underline
  def parse_style("s"), do: :strike_through
  def parse_style("c_db342e"), do: :red
  def parse_style("c_f27806"), do: :orange
  def parse_style("c_f7b503"), do: :yellow
  def parse_style("c_15a85f"), do: :green
  def parse_style("f_13"), do: :small
  def parse_style("f_18"), do: :big
  def parse_style("lst_1"), do: :unordered_list
  def parse_style("lst_2"), do: :ordered_list

  def parse_style("ind_" <> size_str) do
    {:indent, String.to_integer(size_str)}
  end
end
