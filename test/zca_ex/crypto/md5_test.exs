defmodule ZcaEx.Crypto.MD5Test do
  use ExUnit.Case, async: true

  alias ZcaEx.Crypto.MD5

  @fixtures_path "test/fixtures/crypto_fixtures.json"

  setup_all do
    fixtures = @fixtures_path |> File.read!() |> Jason.decode!()
    {:ok, fixtures: fixtures}
  end

  describe "hash_hex/1" do
    test "matches JS implementation for all fixtures", %{fixtures: fixtures} do
      for %{"input" => input, "output" => expected} <- fixtures["md5"] do
        assert MD5.hash_hex(input) == expected,
               "Failed for input: #{inspect(input)}"
      end
    end

    test "returns raw binary hash" do
      hash = MD5.hash("hello")
      assert byte_size(hash) == 16
      assert is_binary(hash)
    end
  end
end
