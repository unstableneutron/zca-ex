defmodule ZcaEx.CookieJar do
  @moduledoc "Cookie jar for managing HTTP cookies per account"

  def child_spec(opts) do
    account_id = Keyword.fetch!(opts, :account_id)

    %{
      id: {__MODULE__, account_id},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  defdelegate start_link(opts), to: ZcaEx.CookieJar.Jar
  defdelegate store(account_id, uri, header), to: ZcaEx.CookieJar.Jar
  defdelegate get_cookie_string(account_id, uri), to: ZcaEx.CookieJar.Jar
  defdelegate export(account_id), to: ZcaEx.CookieJar.Jar
  defdelegate import(account_id, cookies), to: ZcaEx.CookieJar.Jar
end
