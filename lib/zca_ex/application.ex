defmodule ZcaEx.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Process registry for uniqueness enforcement
      {Registry, keys: :unique, name: ZcaEx.Registry},
      
      # Dynamic supervisor for per-account supervision trees
      {DynamicSupervisor, name: ZcaEx.AccountSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: ZcaEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
