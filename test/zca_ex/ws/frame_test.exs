defmodule ZcaEx.WS.FrameTest do
  use ExUnit.Case, async: true

  alias ZcaEx.WS.Frame

  describe "decode/1" do
    test "decodes valid frame with JSON data" do
      json = ~s({"msg":"hello","count":42})
      frame = <<1, 254, 1, 2>> <> json

      assert {:ok, {1, 510, 2}, %{"msg" => "hello", "count" => 42}} = Frame.decode(frame)
    end

    test "decodes frame with empty payload (header only)" do
      frame = <<1, 0, 0, 5>>

      assert {:ok, {1, 0, 5}, %{}} = Frame.decode(frame)
    end

    test "decodes cmd as little-endian uint16" do
      frame = <<1, 0xFF, 0x01, 3>> <> ~s({})

      assert {:ok, {1, 511, 3}, %{}} = Frame.decode(frame)
    end

    test "returns error for frame too short" do
      assert {:error, :invalid_frame_too_short} = Frame.decode(<<1, 2, 3>>)
      assert {:error, :invalid_frame_too_short} = Frame.decode(<<>>)
    end

    test "returns error for invalid JSON payload" do
      frame = <<1, 0, 0, 1>> <> "not json"

      assert {:error, {:json_decode_error, _}} = Frame.decode(frame)
    end

    test "returns error for non-binary input" do
      assert {:error, :invalid_frame} = Frame.decode(nil)
      assert {:error, :invalid_frame} = Frame.decode(123)
    end
  end

  describe "encode/4" do
    test "encodes frame with header and JSON payload" do
      frame = Frame.encode(1, 510, 2, %{"msg" => "test"})

      assert <<1, 254, 1, 2, rest::binary>> = frame
      assert {:ok, %{"msg" => "test"}} = Jason.decode(rest)
    end

    test "encodes cmd as little-endian uint16" do
      frame = Frame.encode(1, 511, 1, %{})

      assert <<1, 0xFF, 0x01, 1, _::binary>> = frame
    end

    test "encodes empty map as empty JSON object" do
      frame = Frame.encode(1, 0, 0, %{})

      assert <<1, 0, 0, 0, json::binary>> = frame
      assert json == "{}"
    end
  end

  describe "encode/decode round-trip" do
    test "data survives round-trip encoding and decoding" do
      original_data = %{"key" => "value", "nested" => %{"a" => 1}}

      frame = Frame.encode(2, 1000, 5, original_data)
      assert {:ok, {2, 1000, 5}, decoded_data} = Frame.decode(frame)
      assert decoded_data == original_data
    end
  end

  describe "ping_frame/0" do
    test "builds valid ping frame with version=1, cmd=2, subCmd=1" do
      frame = Frame.ping_frame()

      assert {:ok, {1, 2, 1}, data} = Frame.decode(frame)
      assert is_integer(data["eventId"])
      assert data["eventId"] > 0
    end
  end

  describe "old_messages_frame/2" do
    test "builds frame for user thread with cmd=510" do
      frame = Frame.old_messages_frame(:user, "12345")

      assert {:ok, {1, 510, 1}, data} = Frame.decode(frame)
      assert data == %{"first" => true, "lastId" => "12345", "preIds" => []}
    end

    test "builds frame for group thread with cmd=511" do
      frame = Frame.old_messages_frame(:group, 67890)

      assert {:ok, {1, 511, 1}, data} = Frame.decode(frame)
      assert data == %{"first" => true, "lastId" => 67890, "preIds" => []}
    end
  end

  describe "old_reactions_frame/2" do
    test "builds frame for user thread with cmd=610" do
      frame = Frame.old_reactions_frame(:user, "abc")

      assert {:ok, {1, 610, 1}, data} = Frame.decode(frame)
      assert data == %{"first" => true, "lastId" => "abc", "preIds" => []}
    end

    test "builds frame for group thread with cmd=611" do
      frame = Frame.old_reactions_frame(:group, "xyz")

      assert {:ok, {1, 611, 1}, data} = Frame.decode(frame)
      assert data == %{"first" => true, "lastId" => "xyz", "preIds" => []}
    end
  end
end
