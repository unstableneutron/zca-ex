defmodule ZcaEx do
  @moduledoc "Zalo API client for Elixir"

  alias ZcaEx.Account.{Credentials, Manager, Supervisor}

  @doc "Add a new Zalo account"
  @spec add_account(String.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def add_account(account_id, opts) do
    with {:ok, credentials} <- Credentials.new(opts) do
      DynamicSupervisor.start_child(
        ZcaEx.AccountSupervisor,
        {Supervisor, account_id: account_id, credentials: credentials}
      )
    end
  end

  @doc "Start a new account with pre-built credentials"
  @spec start_account(term(), Credentials.t()) :: {:ok, pid()} | {:error, term()}
  def start_account(account_id, %Credentials{} = credentials) do
    DynamicSupervisor.start_child(
      ZcaEx.AccountSupervisor,
      {Supervisor, account_id: account_id, credentials: credentials}
    )
  end

  @doc "Remove an account"
  @spec remove_account(String.t()) :: :ok | {:error, :not_found}
  def remove_account(account_id) do
    case Registry.lookup(ZcaEx.Registry, {:account_sup, account_id}) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(ZcaEx.AccountSupervisor, pid)

      [] ->
        {:error, :not_found}
    end
  end

  @doc "Stop an account (alias for remove_account)"
  @spec stop_account(term()) :: :ok | {:error, :not_found}
  defdelegate stop_account(account_id), to: __MODULE__, as: :remove_account

  @doc "Login to a Zalo account"
  @spec login(String.t()) :: {:ok, ZcaEx.Account.Session.t()} | {:error, term()}
  def login(account_id) do
    Manager.login(account_id)
  end

  @doc "Get session for an account"
  @spec get_session(String.t()) :: ZcaEx.Account.Session.t() | nil
  def get_session(account_id) do
    Manager.get_session(account_id)
  end

  @doc "List all registered account IDs"
  @spec list_accounts() :: [String.t()]
  def list_accounts do
    Registry.select(ZcaEx.Registry, [
      {{{:account_sup, :"$1"}, :_, :_}, [], [:"$1"]}
    ])
  end
end
