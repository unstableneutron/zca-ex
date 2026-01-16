defmodule ZcaTest do
  use ExUnit.Case
  doctest Zca

  test "greets the world" do
    assert Zca.hello() == :world
  end
end
