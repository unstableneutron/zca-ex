defmodule ZcaEx.Model.MentionTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Model.Mention

  describe "new/3" do
    test "creates a normal mention with type 0" do
      mention = Mention.new("123456", 5, 10)

      assert mention.uid == "123456"
      assert mention.pos == 5
      assert mention.len == 10
      assert mention.type == 0
    end
  end

  describe "new_all/2" do
    test "creates an @all mention with type 1" do
      mention = Mention.new_all(0, 4)

      assert mention.uid == "-1"
      assert mention.pos == 0
      assert mention.len == 4
      assert mention.type == 1
    end
  end

  describe "from_map/1" do
    test "parses map with all fields" do
      map = %{"uid" => "123456", "pos" => 5, "len" => 10, "type" => 0}
      mention = Mention.from_map(map)

      assert mention.uid == "123456"
      assert mention.pos == 5
      assert mention.len == 10
      assert mention.type == 0
    end

    test "parses map without type (defaults to 0)" do
      map = %{"uid" => "123456", "pos" => 5, "len" => 10}
      mention = Mention.from_map(map)

      assert mention.type == 0
    end

    test "converts numeric uid to string" do
      map = %{"uid" => 123456, "pos" => 5, "len" => 10, "type" => 1}
      mention = Mention.from_map(map)

      assert mention.uid == "123456"
    end
  end

  describe "to_api_format/1" do
    test "converts mention to API map format" do
      mention = %Mention{uid: "123456", pos: 5, len: 10, type: 0}
      api_format = Mention.to_api_format(mention)

      assert api_format == %{"uid" => "123456", "pos" => 5, "len" => 10, "type" => 0}
    end

    test "preserves @all mention format" do
      mention = Mention.new_all(0, 4)
      api_format = Mention.to_api_format(mention)

      assert api_format == %{"uid" => "-1", "pos" => 0, "len" => 4, "type" => 1}
    end
  end
end
