defmodule ZcaEx.WS.RouterTest do
  use ExUnit.Case, async: true

  alias ZcaEx.WS.Router

  describe "route/1" do
    test "routes cipher_key event (cmd=1, subCmd=1)" do
      assert {:cipher_key, nil} = Router.route({1, 1, 1})
    end

    test "routes ping event (cmd=2, subCmd=1)" do
      assert {:ping, nil} = Router.route({1, 2, 1})
    end

    test "routes user message (cmd=501, subCmd=0)" do
      assert {:message, :user} = Router.route({1, 501, 0})
    end

    test "routes group message (cmd=521, subCmd=0)" do
      assert {:message, :group} = Router.route({1, 521, 0})
    end

    test "routes control event (cmd=601, subCmd=0)" do
      assert {:control, nil} = Router.route({1, 601, 0})
    end

    test "routes real-time reaction (cmd=612)" do
      assert {:reaction, nil} = Router.route({1, 612, 0})
      assert {:reaction, nil} = Router.route({1, 612, 1})
    end

    test "routes user old reactions (cmd=610, subCmd=1)" do
      assert {:old_reactions, :user} = Router.route({1, 610, 1})
    end

    test "routes group old reactions (cmd=611, subCmd=1)" do
      assert {:old_reactions, :group} = Router.route({1, 611, 1})
    end

    test "routes user old messages (cmd=510, subCmd=1)" do
      assert {:old_messages, :user} = Router.route({1, 510, 1})
    end

    test "routes group old messages (cmd=511, subCmd=1)" do
      assert {:old_messages, :group} = Router.route({1, 511, 1})
    end

    test "routes typing event (cmd=602, subCmd=0)" do
      assert {:typing, nil} = Router.route({1, 602, 0})
    end

    test "routes user seen/delivered (cmd=502, subCmd=0)" do
      assert {:seen_delivered, :user} = Router.route({1, 502, 0})
    end

    test "routes group seen/delivered (cmd=522, subCmd=0)" do
      assert {:seen_delivered, :group} = Router.route({1, 522, 0})
    end

    test "routes duplicate connection (cmd=3000, subCmd=0)" do
      assert {:duplicate, nil} = Router.route({1, 3000, 0})
    end

    test "returns unknown for unrecognized commands" do
      assert {:unknown, nil} = Router.route({1, 9999, 0})
      assert {:unknown, nil} = Router.route({1, 123, 45})
    end

    test "ignores version when routing" do
      assert {:cipher_key, nil} = Router.route({2, 1, 1})
      assert {:message, :user} = Router.route({99, 501, 0})
    end
  end

  describe "needs_decryption?/1" do
    test "returns true for events requiring decryption" do
      assert Router.needs_decryption?(:message) == true
      assert Router.needs_decryption?(:reaction) == true
      assert Router.needs_decryption?(:old_reactions) == true
      assert Router.needs_decryption?(:old_messages) == true
      assert Router.needs_decryption?(:typing) == true
      assert Router.needs_decryption?(:delivered) == true
      assert Router.needs_decryption?(:seen) == true
    end

    test "returns false for events not requiring decryption" do
      assert Router.needs_decryption?(:cipher_key) == false
      assert Router.needs_decryption?(:ping) == false
      assert Router.needs_decryption?(:control) == false
      assert Router.needs_decryption?(:duplicate) == false
      assert Router.needs_decryption?(:unknown) == false
    end
  end

  describe "needs_decompression?/1" do
    test "returns false for encrypt type 0 (no encryption)" do
      assert Router.needs_decompression?(0) == false
    end

    test "returns true for encrypt type 1 (encrypted + compressed)" do
      assert Router.needs_decompression?(1) == true
    end

    test "returns true for encrypt type 2 (URL-encoded + encrypted + compressed)" do
      assert Router.needs_decompression?(2) == true
    end

    test "returns false for encrypt type 3 (encrypted, no compression)" do
      assert Router.needs_decompression?(3) == false
    end
  end
end
