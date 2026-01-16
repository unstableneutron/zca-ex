defmodule ZcaEx.Model.TextStyleTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Model.TextStyle

  describe "new/3" do
    test "creates a text style" do
      style = TextStyle.new(0, 5, :bold)

      assert style.start == 0
      assert style.len == 5
      assert style.style == :bold
    end

    test "creates indent style with size" do
      style = TextStyle.new(0, 10, {:indent, 2})

      assert style.start == 0
      assert style.len == 10
      assert style.style == {:indent, 2}
    end
  end

  describe "style_to_api/1" do
    test "converts basic styles" do
      assert TextStyle.style_to_api(:bold) == "b"
      assert TextStyle.style_to_api(:italic) == "i"
      assert TextStyle.style_to_api(:underline) == "u"
      assert TextStyle.style_to_api(:strike_through) == "s"
    end

    test "converts color styles" do
      assert TextStyle.style_to_api(:red) == "c_db342e"
      assert TextStyle.style_to_api(:orange) == "c_f27806"
      assert TextStyle.style_to_api(:yellow) == "c_f7b503"
      assert TextStyle.style_to_api(:green) == "c_15a85f"
    end

    test "converts size styles" do
      assert TextStyle.style_to_api(:small) == "f_13"
      assert TextStyle.style_to_api(:big) == "f_18"
    end

    test "converts list styles" do
      assert TextStyle.style_to_api(:unordered_list) == "lst_1"
      assert TextStyle.style_to_api(:ordered_list) == "lst_2"
    end

    test "converts indent with size" do
      assert TextStyle.style_to_api({:indent, 1}) == "ind_1"
      assert TextStyle.style_to_api({:indent, 4}) == "ind_4"
    end
  end

  describe "to_api_format/1" do
    test "converts basic style to API format" do
      style = TextStyle.new(0, 5, :bold)
      api_format = TextStyle.to_api_format(style)

      assert api_format == %{"start" => 0, "len" => 5, "st" => "b"}
    end

    test "converts indent style with indentSize" do
      style = TextStyle.new(0, 10, {:indent, 2})
      api_format = TextStyle.to_api_format(style)

      assert api_format == %{"start" => 0, "len" => 10, "st" => "ind_2", "indentSize" => 2}
    end
  end

  describe "parse_style/1" do
    test "parses basic styles" do
      assert TextStyle.parse_style("b") == :bold
      assert TextStyle.parse_style("i") == :italic
      assert TextStyle.parse_style("u") == :underline
      assert TextStyle.parse_style("s") == :strike_through
    end

    test "parses color styles" do
      assert TextStyle.parse_style("c_db342e") == :red
      assert TextStyle.parse_style("c_f27806") == :orange
      assert TextStyle.parse_style("c_f7b503") == :yellow
      assert TextStyle.parse_style("c_15a85f") == :green
    end

    test "parses size styles" do
      assert TextStyle.parse_style("f_13") == :small
      assert TextStyle.parse_style("f_18") == :big
    end

    test "parses list styles" do
      assert TextStyle.parse_style("lst_1") == :unordered_list
      assert TextStyle.parse_style("lst_2") == :ordered_list
    end

    test "parses indent styles" do
      assert TextStyle.parse_style("ind_1") == {:indent, 1}
      assert TextStyle.parse_style("ind_4") == {:indent, 4}
    end
  end
end
