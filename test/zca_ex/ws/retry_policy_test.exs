defmodule ZcaEx.WS.RetryPolicyTest do
  use ExUnit.Case, async: true

  alias ZcaEx.WS.RetryPolicy

  describe "new/2" do
    test "creates policy with defaults" do
      policy = RetryPolicy.new(3)

      assert policy.total_endpoints == 3
      assert policy.base_delay_ms == 100
      assert policy.max_delay_ms == 30_000
      assert policy.max_attempts_per_endpoint == 3
      assert policy.max_total_attempts == 15
      assert policy.current_attempt == 0
      assert policy.endpoint_index == 0
      assert policy.endpoint_attempts == 0
    end

    test "creates policy with custom options" do
      policy =
        RetryPolicy.new(2,
          base_delay_ms: 200,
          max_delay_ms: 10_000,
          max_attempts_per_endpoint: 5,
          max_total_attempts: 20
        )

      assert policy.total_endpoints == 2
      assert policy.base_delay_ms == 200
      assert policy.max_delay_ms == 10_000
      assert policy.max_attempts_per_endpoint == 5
      assert policy.max_total_attempts == 20
    end
  end

  describe "next_delay/1" do
    test "returns increasing delays with backoff" do
      policy = RetryPolicy.new(3, base_delay_ms: 100, max_delay_ms: 10_000)

      {:retry, delay1, policy} = RetryPolicy.next_delay(policy)
      {:retry, delay2, policy} = RetryPolicy.next_delay(policy)
      {:retry, delay3, _policy} = RetryPolicy.next_delay(policy)

      assert delay1 >= 75 and delay1 <= 125
      assert delay2 >= 150 and delay2 <= 250
      assert delay3 >= 300 and delay3 <= 500
    end

    test "caps delay at max_delay_ms" do
      policy = RetryPolicy.new(1, base_delay_ms: 1000, max_delay_ms: 2000, max_total_attempts: 10)

      {:retry, _delay1, policy} = RetryPolicy.next_delay(policy)
      {:retry, _delay2, policy} = RetryPolicy.next_delay(policy)
      {:retry, delay3, _policy} = RetryPolicy.next_delay(policy)

      assert delay3 <= 2500
    end

    test "rotates endpoint after max_attempts_per_endpoint" do
      policy = RetryPolicy.new(3, max_attempts_per_endpoint: 2)

      assert policy.endpoint_index == 0
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      assert policy.endpoint_index == 0
      assert policy.endpoint_attempts == 1
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      assert policy.endpoint_index == 0
      assert policy.endpoint_attempts == 2
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      assert policy.endpoint_index == 1
      assert policy.endpoint_attempts == 1
    end

    test "wraps endpoint index when exceeding total_endpoints" do
      policy = RetryPolicy.new(2, max_attempts_per_endpoint: 2, max_total_attempts: 100)

      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      assert policy.endpoint_index == 0

      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      assert policy.endpoint_index == 1

      policy = RetryPolicy.reset(policy)

      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      assert policy.endpoint_index == 0
    end

    test "halts when max_total_attempts exceeded" do
      policy = RetryPolicy.new(3, max_total_attempts: 2)

      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      result = RetryPolicy.next_delay(policy)

      assert result == {:halt, :max_attempts_exceeded}
    end

    test "halts when all endpoints exhausted" do
      policy = RetryPolicy.new(2, max_attempts_per_endpoint: 2, max_total_attempts: 100)

      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      result = RetryPolicy.next_delay(policy)

      assert result == {:halt, :all_endpoints_failed}
    end
  end

  describe "reset/1" do
    test "clears attempt counters" do
      policy = RetryPolicy.new(3)
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)
      {:retry, _d, policy} = RetryPolicy.next_delay(policy)

      assert policy.current_attempt == 2
      assert policy.endpoint_attempts == 2

      reset_policy = RetryPolicy.reset(policy)

      assert reset_policy.current_attempt == 0
      assert reset_policy.endpoint_attempts == 0
      assert reset_policy.endpoint_index == policy.endpoint_index
    end
  end

  describe "should_rotate_endpoint?/1" do
    test "returns false when under max_attempts_per_endpoint" do
      policy = RetryPolicy.new(3, max_attempts_per_endpoint: 3)
      policy = %{policy | endpoint_attempts: 2}

      refute RetryPolicy.should_rotate_endpoint?(policy)
    end

    test "returns true when at max_attempts_per_endpoint" do
      policy = RetryPolicy.new(3, max_attempts_per_endpoint: 3)
      policy = %{policy | endpoint_attempts: 3}

      assert RetryPolicy.should_rotate_endpoint?(policy)
    end
  end

  describe "calculate_delay/3" do
    test "applies exponential backoff" do
      delays =
        for attempt <- 0..4 do
          avg =
            for _ <- 1..100 do
              RetryPolicy.calculate_delay(attempt, 100, 100_000)
            end
            |> Enum.sum()
            |> div(100)

          avg
        end

      assert Enum.at(delays, 1) > Enum.at(delays, 0)
      assert Enum.at(delays, 2) > Enum.at(delays, 1)
      assert Enum.at(delays, 3) > Enum.at(delays, 2)
    end

    test "respects max_delay" do
      delay = RetryPolicy.calculate_delay(20, 100, 1000)
      assert delay <= 1250
    end

    test "applies jitter within ±25%" do
      delays = for _ <- 1..100, do: RetryPolicy.calculate_delay(0, 100, 10_000)

      assert Enum.min(delays) >= 75
      assert Enum.max(delays) <= 125
    end
  end
end
