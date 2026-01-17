defmodule ZcaEx do
  @moduledoc "Zalo API client for Elixir"

  alias ZcaEx.Account.{Credentials, Manager, Runtime, Supervisor}

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

  @doc """
  Ensures an account's supervised tree is started. Idempotent - returns existing pid if already started.

  Options:
    - :session - Optional pre-existing session (e.g., from QR login). If provided, skips login.
    
  Returns {:ok, pid} where pid is the Account.Supervisor pid.
  """
  @spec ensure_account_started(term(), Credentials.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def ensure_account_started(account_id, %Credentials{} = credentials, opts \\ []) do
    session = Keyword.get(opts, :session)

    child_opts = [
      account_id: account_id,
      credentials: credentials,
      session: session
    ]

    case DynamicSupervisor.start_child(ZcaEx.AccountSupervisor, {Supervisor, child_opts}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Returns the pid of the account supervisor if started, nil otherwise"
  @spec account_started?(term()) :: pid() | nil
  def account_started?(account_id) do
    case Registry.lookup(ZcaEx.Registry, {:account_sup, account_id}) do
      [{pid, _}] -> pid
      [] -> nil
    end
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

  # Runtime convenience APIs

  @doc "Get account runtime status (phase, config)"
  @spec account_status(String.t()) :: {:ok, map()} | {:error, term()}
  def account_status(account_id) do
    Runtime.status(account_id)
  end

  @doc "Configure account runtime (auto_login, ws.auto_connect, etc.)"
  @spec configure_account(String.t(), keyword() | map()) :: :ok
  def configure_account(account_id, opts) do
    Runtime.configure(account_id, opts)
  end

  @doc "Force account to reconcile (retry login/WS connect if needed)"
  @spec reconnect(String.t()) :: :ok
  def reconnect(account_id) do
    Runtime.reconcile(account_id)
  end

  @doc "Disable auto-login and auto-connect for an account"
  @spec pause_account(String.t()) :: :ok
  def pause_account(account_id) do
    Runtime.stop(account_id)
  end
end
