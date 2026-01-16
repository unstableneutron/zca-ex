defmodule ZcaEx.HTTP.AccountClientTest do
  use ExUnit.Case, async: true

  describe "sanitize_filename/1" do
    test "passes through normal filenames" do
      assert sanitize_filename("normal.jpg") == "normal.jpg"
    end

    test "escapes double quotes" do
      assert sanitize_filename("file\"name.jpg") == "file\\\"name.jpg"
    end

    test "removes CR and LF characters" do
      assert sanitize_filename("file\r\nname.jpg") == "filename.jpg"
    end

    test "handles combined malicious input" do
      assert sanitize_filename("bad\"\r\nfile.jpg") == "bad\\\"file.jpg"
    end
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace("\"", "\\\"")
    |> String.replace(~r/[\r\n]/, "")
  end
end
