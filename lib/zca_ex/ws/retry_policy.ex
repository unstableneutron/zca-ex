defmodule ZcaEx.WS.RetryPolicy do
  @moduledoc """
  Exponential backoff with jitter and endpoint rotation for WebSocket reconnection.

  Implements a retry policy that:
  - Uses exponential backoff with ±25% jitter to avoid thundering herd
  - Rotates through available endpoints after max attempts per endpoint
  - Tracks total attempts across all endpoints to prevent infinite retries
  """

  @default_base_delay_ms 100
  @default_max_delay_ms 30_000
  @default_max_attempts_per_endpoint 3
  @default_max_total_attempts 15

  defstruct base_delay_ms: @default_base_delay_ms,
            max_delay_ms: @default_max_delay_ms,
            max_attempts_per_endpoint: @default_max_attempts_per_endpoint,
            max_total_attempts: @default_max_total_attempts,
            current_attempt: 0,
            endpoint_index: 0,
            endpoint_attempts: 0,
            total_endpoints: 1

  @type t :: %__MODULE__{
          base_delay_ms: pos_integer(),
          max_delay_ms: pos_integer(),
          max_attempts_per_endpoint: pos_integer(),
          max_total_attempts: pos_integer(),
          current_attempt: non_neg_integer(),
          endpoint_index: non_neg_integer(),
          endpoint_attempts: non_neg_integer(),
          total_endpoints: pos_integer()
        }

  @doc """
  Create a new retry policy.

  ## Options
    * `:base_delay_ms` - Base delay in milliseconds (default: #{@default_base_delay_ms})
    * `:max_delay_ms` - Maximum delay in milliseconds (default: #{@default_max_delay_ms})
    * `:max_attempts_per_endpoint` - Max retries per endpoint before rotating (default: #{@default_max_attempts_per_endpoint})
    * `:max_total_attempts` - Max total retries across all endpoints (default: #{@default_max_total_attempts})
  """
  @spec new(pos_integer(), keyword()) :: t()
  def new(total_endpoints, opts \\ []) when total_endpoints > 0 do
    %__MODULE__{
      total_endpoints: total_endpoints,
      base_delay_ms: Keyword.get(opts, :base_delay_ms, @default_base_delay_ms),
      max_delay_ms: Keyword.get(opts, :max_delay_ms, @default_max_delay_ms),
      max_attempts_per_endpoint:
        Keyword.get(opts, :max_attempts_per_endpoint, @default_max_attempts_per_endpoint),
      max_total_attempts: Keyword.get(opts, :max_total_attempts, @default_max_total_attempts)
    }
  end

  @doc """
  Get the next delay and updated policy, or halt if max attempts exceeded.

  Returns:
    * `{:retry, delay_ms, updated_policy}` - Retry with the given delay
    * `{:halt, :max_attempts_exceeded}` - Max total attempts reached
    * `{:halt, :all_endpoints_failed}` - All endpoints exhausted (when total_attempts >= total_endpoints * max_per_endpoint)
  """
  @spec next_delay(t()) ::
          {:retry, pos_integer(), t()}
          | {:halt, :max_attempts_exceeded}
          | {:halt, :all_endpoints_failed}
  def next_delay(%__MODULE__{} = policy) do
    cond do
      policy.current_attempt >= policy.max_total_attempts ->
        {:halt, :max_attempts_exceeded}

      all_endpoints_exhausted?(policy) ->
        {:halt, :all_endpoints_failed}

      true ->
        policy = maybe_rotate_endpoint(policy)

        delay =
          calculate_delay(policy.endpoint_attempts, policy.base_delay_ms, policy.max_delay_ms)

        updated_policy = %{
          policy
          | current_attempt: policy.current_attempt + 1,
            endpoint_attempts: policy.endpoint_attempts + 1
        }

        {:retry, delay, updated_policy}
    end
  end

  @doc """
  Reset attempt counters after a successful connection.
  """
  @spec reset(t()) :: t()
  def reset(%__MODULE__{} = policy) do
    %{policy | current_attempt: 0, endpoint_attempts: 0}
  end

  @doc """
  Check if the policy should rotate to the next endpoint.
  """
  @spec should_rotate_endpoint?(t()) :: boolean()
  def should_rotate_endpoint?(%__MODULE__{} = policy) do
    policy.endpoint_attempts >= policy.max_attempts_per_endpoint
  end

  @doc """
  Calculate delay with exponential backoff and ±25% jitter.

  Formula: min(max_delay, base_delay * 2^attempt) with ±25% random jitter
  """
  @spec calculate_delay(non_neg_integer(), pos_integer(), pos_integer()) :: pos_integer()
  def calculate_delay(attempt, base_delay_ms, max_delay_ms) do
    exponential = min(max_delay_ms, base_delay_ms * :math.pow(2, attempt))
    jitter_factor = 0.75 + :rand.uniform() * 0.5
    round(exponential * jitter_factor)
  end

  # Private functions

  defp all_endpoints_exhausted?(%__MODULE__{} = policy) do
    max_possible = policy.total_endpoints * policy.max_attempts_per_endpoint
    policy.current_attempt >= max_possible
  end

  defp maybe_rotate_endpoint(%__MODULE__{} = policy) do
    if should_rotate_endpoint?(policy) do
      next_index = rem(policy.endpoint_index + 1, policy.total_endpoints)
      %{policy | endpoint_index: next_index, endpoint_attempts: 0}
    else
      policy
    end
  end
end
