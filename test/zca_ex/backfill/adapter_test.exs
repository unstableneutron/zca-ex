defmodule ZcaEx.Backfill.AdapterTest do
  use ExUnit.Case, async: false

  alias ZcaEx.Backfill.Adapter

  describe "fetch_old_messages_page/4" do
    test "returns {:error, :not_found} when connection does not exist" do
      account_id = "nonexistent_account_#{:erlang.unique_integer([:positive])}"

      result = Adapter.fetch_old_messages_page(account_id, :user)
      assert result == {:error, :not_found}
    end
  end

  describe "fetch_old_reactions_page/4" do
    test "returns {:error, :not_found} when connection does not exist" do
      account_id = "nonexistent_reactions_#{:erlang.unique_integer([:positive])}"

      result = Adapter.fetch_old_reactions_page(account_id, :group)
      assert result == {:error, :not_found}
    end
  end
end
