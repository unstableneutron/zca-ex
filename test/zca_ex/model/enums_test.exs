defmodule ZcaEx.Model.EnumsTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Model.Enums

  describe "thread_type_value/1" do
    test "returns 0 for :user" do
      assert Enums.thread_type_value(:user) == 0
    end

    test "returns 1 for :group" do
      assert Enums.thread_type_value(:group) == 1
    end
  end

  describe "dest_type_value/1" do
    test "returns 1 for :group" do
      assert Enums.dest_type_value(:group) == 1
    end

    test "returns 3 for :user" do
      assert Enums.dest_type_value(:user) == 3
    end

    test "returns 5 for :page" do
      assert Enums.dest_type_value(:page) == 5
    end
  end

  describe "gender_value/1" do
    test "returns 0 for :male" do
      assert Enums.gender_value(:male) == 0
    end

    test "returns 1 for :female" do
      assert Enums.gender_value(:female) == 1
    end
  end

  describe "reaction_icon/1" do
    test "returns correct icon strings" do
      assert Enums.reaction_icon(:heart) == "/-heart"
      assert Enums.reaction_icon(:like) == "/-strong"
      assert Enums.reaction_icon(:haha) == ":>"
      assert Enums.reaction_icon(:wow) == ":o"
      assert Enums.reaction_icon(:cry) == ":-(("
      assert Enums.reaction_icon(:angry) == ":-h"
      assert Enums.reaction_icon(:kiss) == ":-*"
      assert Enums.reaction_icon(:tears_of_joy) == ":')"
      assert Enums.reaction_icon(:shit) == "/-shit"
      assert Enums.reaction_icon(:rose) == "/-rose"
      assert Enums.reaction_icon(:broken_heart) == "/-break"
      assert Enums.reaction_icon(:dislike) == "/-weak"
      assert Enums.reaction_icon(:beer) == "/-beer"
    end
  end

  describe "reaction_type/1" do
    test "returns correct type and source for basic reactions" do
      assert Enums.reaction_type(:haha) == {0, 6}
      assert Enums.reaction_type(:like) == {3, 6}
      assert Enums.reaction_type(:heart) == {5, 6}
      assert Enums.reaction_type(:wow) == {32, 6}
      assert Enums.reaction_type(:cry) == {2, 6}
      assert Enums.reaction_type(:angry) == {20, 6}
    end

    test "returns correct type and source for extended reactions" do
      assert Enums.reaction_type(:kiss) == {8, 6}
      assert Enums.reaction_type(:tears_of_joy) == {7, 6}
      assert Enums.reaction_type(:shit) == {66, 6}
      assert Enums.reaction_type(:rose) == {120, 6}
      assert Enums.reaction_type(:broken_heart) == {65, 6}
      assert Enums.reaction_type(:dislike) == {4, 6}
    end

    test "all reactions have source 6" do
      reactions = [
        :like, :heart, :haha, :wow, :cry, :angry, :kiss, :tears_of_joy,
        :shit, :rose, :broken_heart, :dislike, :love, :confused, :wink,
        :fade, :sun, :birthday, :bomb, :ok, :peace, :thanks, :punch,
        :share, :pray, :no, :bad, :love_you, :sad, :very_sad, :cool,
        :nerd, :big_smile, :sunglasses, :neutral, :sad_face, :bye,
        :sleepy, :wipe, :dig, :anguish, :handclap, :angry_face,
        :f_chair, :l_chair, :r_chair, :silent, :surprise, :embarrassed,
        :afraid, :sad2, :big_laugh, :rich, :beer
      ]

      for reaction <- reactions do
        {_type, source} = Enums.reaction_type(reaction)
        assert source == 6, "Expected source 6 for #{reaction}"
      end
    end
  end
end
