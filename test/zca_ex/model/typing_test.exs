defmodule ZcaEx.Model.TypingTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Model.Typing

  describe "from_ws_data/2 for user typing" do
    test "creates typing event from user typing data" do
      data = %{
        "uid" => "1234567890",
        "ts" => "1737100000000",
        "isPC" => 0
      }

      typing = Typing.from_ws_data(data, "typing")

      assert typing.uid == "1234567890"
      assert typing.ts == "1737100000000"
      assert typing.is_pc == false
      assert typing.thread_id == "1234567890"
      assert typing.thread_type == :user
      assert typing.is_self == false
    end

    test "creates user typing event from PC" do
      data = %{
        "uid" => "1234567890",
        "ts" => "1737100000000",
        "isPC" => 1
      }

      typing = Typing.from_ws_data(data, "typing")

      assert typing.is_pc == true
      assert typing.thread_type == :user
    end
  end

  describe "from_ws_data/2 for group typing" do
    test "creates typing event from group typing data" do
      data = %{
        "uid" => "1234567890",
        "gid" => "group123",
        "ts" => "1737100000000",
        "isPC" => 0
      }

      typing = Typing.from_ws_data(data, "gtyping")

      assert typing.uid == "1234567890"
      assert typing.ts == "1737100000000"
      assert typing.is_pc == false
      assert typing.thread_id == "group123"
      assert typing.thread_type == :group
      assert typing.is_self == false
    end

    test "creates group typing event from PC" do
      data = %{
        "uid" => "1234567890",
        "gid" => "group123",
        "ts" => "1737100000000",
        "isPC" => 1
      }

      typing = Typing.from_ws_data(data, "gtyping")

      assert typing.is_pc == true
      assert typing.thread_type == :group
      assert typing.thread_id == "group123"
    end
  end

  describe "from_ws_data/2 is_self behavior" do
    test "is_self is always false for user typing" do
      data = %{
        "uid" => "1234567890",
        "ts" => "1737100000000",
        "isPC" => 0
      }

      typing = Typing.from_ws_data(data, "typing")

      assert typing.is_self == false
    end

    test "is_self is always false for group typing" do
      data = %{
        "uid" => "1234567890",
        "gid" => "group123",
        "ts" => "1737100000000",
        "isPC" => 0
      }

      typing = Typing.from_ws_data(data, "gtyping")

      assert typing.is_self == false
    end
  end
end
