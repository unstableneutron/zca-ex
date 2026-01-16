defmodule ZcaEx.Model.Enums do
  @moduledoc "Shared enums for Zalo API"

  @type thread_type :: :user | :group

  @type dest_type :: :group | :user | :page

  @type gender :: :male | :female

  @type reaction ::
          :like
          | :heart
          | :haha
          | :wow
          | :cry
          | :angry
          | :kiss
          | :tears_of_joy
          | :shit
          | :rose
          | :broken_heart
          | :dislike
          | :love
          | :confused
          | :wink
          | :fade
          | :sun
          | :birthday
          | :bomb
          | :ok
          | :peace
          | :thanks
          | :punch
          | :share
          | :pray
          | :no
          | :bad
          | :love_you
          | :sad
          | :very_sad
          | :cool
          | :nerd
          | :big_smile
          | :sunglasses
          | :neutral
          | :sad_face
          | :bye
          | :sleepy
          | :wipe
          | :dig
          | :anguish
          | :handclap
          | :angry_face
          | :f_chair
          | :l_chair
          | :r_chair
          | :silent
          | :surprise
          | :embarrassed
          | :afraid
          | :sad2
          | :big_laugh
          | :rich
          | :beer

  @doc "Convert thread type to API integer value"
  @spec thread_type_value(thread_type()) :: 0 | 1
  def thread_type_value(:user), do: 0
  def thread_type_value(:group), do: 1

  @doc "Convert dest type to API integer value"
  @spec dest_type_value(dest_type()) :: 1 | 3 | 5
  def dest_type_value(:group), do: 1
  def dest_type_value(:user), do: 3
  def dest_type_value(:page), do: 5

  @doc "Convert gender to API integer value"
  @spec gender_value(gender()) :: 0 | 1
  def gender_value(:male), do: 0
  def gender_value(:female), do: 1

  @doc "Get reaction icon string for API"
  @spec reaction_icon(reaction()) :: String.t()
  def reaction_icon(:heart), do: "/-heart"
  def reaction_icon(:like), do: "/-strong"
  def reaction_icon(:haha), do: ":>"
  def reaction_icon(:wow), do: ":o"
  def reaction_icon(:cry), do: ":-(("
  def reaction_icon(:angry), do: ":-h"
  def reaction_icon(:kiss), do: ":-*"
  def reaction_icon(:tears_of_joy), do: ":')"
  def reaction_icon(:shit), do: "/-shit"
  def reaction_icon(:rose), do: "/-rose"
  def reaction_icon(:broken_heart), do: "/-break"
  def reaction_icon(:dislike), do: "/-weak"
  def reaction_icon(:love), do: ";xx"
  def reaction_icon(:confused), do: ";-/"
  def reaction_icon(:wink), do: ";-)"
  def reaction_icon(:fade), do: "/-fade"
  def reaction_icon(:sun), do: "/-li"
  def reaction_icon(:birthday), do: "/-bd"
  def reaction_icon(:bomb), do: "/-bome"
  def reaction_icon(:ok), do: "/-ok"
  def reaction_icon(:peace), do: "/-v"
  def reaction_icon(:thanks), do: "/-thanks"
  def reaction_icon(:punch), do: "/-punch"
  def reaction_icon(:share), do: "/-share"
  def reaction_icon(:pray), do: "_()_"
  def reaction_icon(:no), do: "/-no"
  def reaction_icon(:bad), do: "/-bad"
  def reaction_icon(:love_you), do: "/-loveu"
  def reaction_icon(:sad), do: "--b"
  def reaction_icon(:very_sad), do: ":(("
  def reaction_icon(:cool), do: "x-)"
  def reaction_icon(:nerd), do: "8-)"
  def reaction_icon(:big_smile), do: ";-d"
  def reaction_icon(:sunglasses), do: "b-)"
  def reaction_icon(:neutral), do: ":--|"
  def reaction_icon(:sad_face), do: "p-("
  def reaction_icon(:bye), do: ":-bye"
  def reaction_icon(:sleepy), do: "|-)"
  def reaction_icon(:wipe), do: ":wipe"
  def reaction_icon(:dig), do: ":-dig"
  def reaction_icon(:anguish), do: "&-("
  def reaction_icon(:handclap), do: ":handclap"
  def reaction_icon(:angry_face), do: ">-|"
  def reaction_icon(:f_chair), do: ":-f"
  def reaction_icon(:l_chair), do: ":-l"
  def reaction_icon(:r_chair), do: ":-r"
  def reaction_icon(:silent), do: ";-x"
  def reaction_icon(:surprise), do: ":-o"
  def reaction_icon(:embarrassed), do: ";-s"
  def reaction_icon(:afraid), do: ";-a"
  def reaction_icon(:sad2), do: ":-<"
  def reaction_icon(:big_laugh), do: ":))"
  def reaction_icon(:rich), do: "$-)"
  def reaction_icon(:beer), do: "/-beer"

  @doc "Get reaction type and source for API"
  @spec reaction_type(reaction()) :: {r_type :: integer(), source :: integer()}
  def reaction_type(:haha), do: {0, 6}
  def reaction_type(:sad), do: {1, 6}
  def reaction_type(:cry), do: {2, 6}
  def reaction_type(:like), do: {3, 6}
  def reaction_type(:dislike), do: {4, 6}
  def reaction_type(:heart), do: {5, 6}
  def reaction_type(:tears_of_joy), do: {7, 6}
  def reaction_type(:kiss), do: {8, 6}
  def reaction_type(:very_sad), do: {16, 6}
  def reaction_type(:angry), do: {20, 6}
  def reaction_type(:cool), do: {21, 6}
  def reaction_type(:nerd), do: {22, 6}
  def reaction_type(:big_smile), do: {23, 6}
  def reaction_type(:sunglasses), do: {26, 6}
  def reaction_type(:love), do: {29, 6}
  def reaction_type(:neutral), do: {30, 6}
  def reaction_type(:wow), do: {32, 6}
  def reaction_type(:sad_face), do: {35, 6}
  def reaction_type(:bye), do: {36, 6}
  def reaction_type(:sleepy), do: {38, 6}
  def reaction_type(:wipe), do: {39, 6}
  def reaction_type(:dig), do: {42, 6}
  def reaction_type(:anguish), do: {44, 6}
  def reaction_type(:wink), do: {45, 6}
  def reaction_type(:handclap), do: {46, 6}
  def reaction_type(:angry_face), do: {47, 6}
  def reaction_type(:f_chair), do: {48, 6}
  def reaction_type(:l_chair), do: {49, 6}
  def reaction_type(:r_chair), do: {50, 6}
  def reaction_type(:confused), do: {51, 6}
  def reaction_type(:silent), do: {52, 6}
  def reaction_type(:surprise), do: {53, 6}
  def reaction_type(:embarrassed), do: {54, 6}
  def reaction_type(:afraid), do: {60, 6}
  def reaction_type(:sad2), do: {61, 6}
  def reaction_type(:big_laugh), do: {62, 6}
  def reaction_type(:rich), do: {63, 6}
  def reaction_type(:broken_heart), do: {65, 6}
  def reaction_type(:shit), do: {66, 6}
  def reaction_type(:sun), do: {67, 6}
  def reaction_type(:ok), do: {68, 6}
  def reaction_type(:peace), do: {69, 6}
  def reaction_type(:thanks), do: {70, 6}
  def reaction_type(:punch), do: {71, 6}
  def reaction_type(:share), do: {72, 6}
  def reaction_type(:pray), do: {73, 6}
  def reaction_type(:beer), do: {99, 6}
  def reaction_type(:rose), do: {120, 6}
  def reaction_type(:fade), do: {121, 6}
  def reaction_type(:birthday), do: {126, 6}
  def reaction_type(:bomb), do: {127, 6}
  def reaction_type(:no), do: {131, 6}
  def reaction_type(:bad), do: {132, 6}
  def reaction_type(:love_you), do: {133, 6}
end
