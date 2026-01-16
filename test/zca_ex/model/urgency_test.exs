defmodule ZcaEx.Model.UrgencyTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Model.Urgency

  describe "to_api_value/1" do
    test "returns 0 for :default" do
      assert Urgency.to_api_value(:default) == 0
    end

    test "returns 1 for :important" do
      assert Urgency.to_api_value(:important) == 1
    end

    test "returns 2 for :urgent" do
      assert Urgency.to_api_value(:urgent) == 2
    end
  end

  describe "from_api_value/1" do
    test "returns :default for 0" do
      assert Urgency.from_api_value(0) == :default
    end

    test "returns :important for 1" do
      assert Urgency.from_api_value(1) == :important
    end

    test "returns :urgent for 2" do
      assert Urgency.from_api_value(2) == :urgent
    end
  end

  describe "roundtrip" do
    test "to_api_value and from_api_value are inverses" do
      for urgency <- [:default, :important, :urgent] do
        assert urgency == urgency |> Urgency.to_api_value() |> Urgency.from_api_value()
      end
    end
  end
end
