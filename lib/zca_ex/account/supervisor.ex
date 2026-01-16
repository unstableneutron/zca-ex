defmodule ZcaEx.Account.Supervisor do
  @moduledoc "Supervisor for a single Zalo account's processes"
  use Supervisor

  alias ZcaEx.Account.Manager
  alias ZcaEx.CookieJar

  def child_spec(opts) do
    account_id = Keyword.fetch!(opts, :account_id)

    %{
      id: {__MODULE__, account_id},
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: :infinity
    }
  end

  def start_link(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    Supervisor.start_link(__MODULE__, opts, name: via(account_id))
  end

  defp via(account_id), do: {:via, Registry, {ZcaEx.Registry, {:account_sup, account_id}}}

  @impl true
  def init(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    credentials = Keyword.fetch!(opts, :credentials)

    children = [
      {CookieJar, account_id: account_id, cookies: credentials.cookies},
      {Manager, account_id: account_id, credentials: credentials}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
