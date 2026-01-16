defmodule ZcaEx.Crypto.SignKeyTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Crypto.SignKey

  @fixtures_path "test/fixtures/crypto_fixtures.json"

  setup_all do
    fixtures = @fixtures_path |> File.read!() |> Jason.decode!()
    {:ok, fixtures: fixtures}
  end

  describe "generate/2" do
    test "matches JS implementation for all fixtures", %{fixtures: fixtures} do
      for fixture <- fixtures["sign_key"] do
        %{
          "type" => type,
          "params" => params,
          "expected" => expected
        } = fixture

        # Convert string keys to atoms for consistency
        params_atom_keys =
          params
          |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
          |> Map.new()

        result = SignKey.generate(type, params_atom_keys)

        assert result == expected,
               "Failed for type: #{type}, expected: #{expected}, got: #{result}"
      end
    end

    test "sorts params by key before hashing" do
      params = %{z: 1, a: 2, m: 3}
      # Same params in different order should produce same result
      params2 = %{a: 2, m: 3, z: 1}

      assert SignKey.generate("test", params) == SignKey.generate("test", params2)
    end

    test "converts non-string values to strings" do
      params = %{num: 123, bool: true, str: "hello"}
      result = SignKey.generate("type", params)
      assert is_binary(result)
      assert String.length(result) == 32
    end
  end
end
