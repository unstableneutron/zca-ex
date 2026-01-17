defmodule ZcaEx.Account do
  @moduledoc "Account health and connection management APIs"

  alias ZcaEx.WS.Connection

  @doc """
  Check if the account's processes are healthy.
  Returns :ok if CookieJar, Manager, and WS.Connection are all alive.
  Returns {:error, reason} if any process is dead or unhealthy.

  Error reasons:
  - :not_found - account not started (all processes missing)
  - :partial_start - some processes exist, some missing (needs reset)
  - :cookie_jar_dead, :manager_dead, :ws_dead - process exists but not alive
  """
  @spec health(term()) ::
          :ok
          | {:error,
             :not_found | :partial_start | :cookie_jar_dead | :manager_dead | :ws_dead}
  def health(account_id) do
    results = [
      {:cookie_jar, lookup_process(:cookie_jar, account_id)},
      {:manager, lookup_process(:manager, account_id)},
      {:ws_connection, lookup_process(:ws_connection, account_id)}
    ]

    all_missing = Enum.all?(results, fn {_, result} -> result == {:error, :not_found} end)
    all_ok = Enum.all?(results, fn {_, result} -> match?({:ok, _}, result) end)

    cond do
      all_ok ->
        :ok

      all_missing ->
        {:error, :not_found}

      true ->
        # Check for dead processes first (more specific)
        dead_process =
          Enum.find_value(results, fn
            {:cookie_jar, {:error, :cookie_jar_dead}} -> :cookie_jar_dead
            {:manager, {:error, :manager_dead}} -> :manager_dead
            {:ws_connection, {:error, :ws_dead}} -> :ws_dead
            _ -> nil
          end)

        if dead_process do
          {:error, dead_process}
        else
          # Some exist, some missing = partial start
          {:error, :partial_start}
        end
    end
  end

  @doc """
  Idempotent "make it good" API.
  Checks health, resets if unhealthy, starts account if not started,
  and connects WS if not connected.

  Returns {:ok, session} on success, {:error, reason} on failure.
  """
  @spec ensure_connected(term(), ZcaEx.Account.Credentials.t(), ZcaEx.Account.Session.t()) ::
          {:ok, ZcaEx.Account.Session.t()} | {:error, term()}
  def ensure_connected(account_id, credentials, session) do
    case health(account_id) do
      :ok ->
        ensure_ws_connected(account_id, session)

      {:error, :not_found} ->
        with {:ok, _pid} <- start_or_get_account(account_id, credentials) do
          ensure_ws_connected(account_id, session)
        end

      {:error, reason}
      when reason in [:cookie_jar_dead, :manager_dead, :ws_dead, :partial_start] ->
        with :ok <- reset(account_id),
             {:ok, _pid} <- start_or_get_account(account_id, credentials) do
          ensure_ws_connected(account_id, session)
        end
    end
  end

  defp start_or_get_account(account_id, credentials) do
    case ZcaEx.start_account(account_id, credentials) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Hard restart of the entire account subtree.
  Removes the account and lets it be re-added.
  """
  @spec reset(term()) :: :ok | {:error, term()}
  def reset(account_id) do
    case ZcaEx.remove_account(account_id) do
      :ok -> :ok
      {:error, :not_found} -> :ok
      error -> error
    end
  end

  defp lookup_process(type, account_id) do
    registry_key = registry_key(type, account_id)

    case Registry.lookup(ZcaEx.Registry, registry_key) do
      [{pid, _}] when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          {:error, process_dead_error(type)}
        end

      [] ->
        {:error, :not_found}
    end
  end

  defp registry_key(:cookie_jar, account_id), do: {:cookie_jar, account_id}
  defp registry_key(:manager, account_id), do: {:account, account_id}
  defp registry_key(:ws_connection, account_id), do: {:ws, account_id}

  defp process_dead_error(:cookie_jar), do: :cookie_jar_dead
  defp process_dead_error(:manager), do: :manager_dead
  defp process_dead_error(:ws_connection), do: :ws_dead

  defp ensure_ws_connected(account_id, session) do
    case Connection.connection_status(account_id) do
      {:ok, %{state: :ready}} ->
        {:ok, session}

      {:ok, %{state: :connected}} ->
        {:ok, session}

      {:ok, _status} ->
        case Connection.connect(account_id, session) do
          :ok -> {:ok, session}
          {:error, :already_connected} -> {:ok, session}
          error -> error
        end

      {:error, :not_found} ->
        {:error, :ws_dead}
    end
  end
end
