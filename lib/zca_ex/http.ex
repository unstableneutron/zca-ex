defmodule ZcaEx.HTTP do
  @moduledoc "HTTP utilities for Zalo API"

  alias ZcaEx.HTTP.{Client, HeaderBuilder, URL}

  defdelegate build_url(base, params \\ %{}, opts \\ []), to: URL, as: :build
  defdelegate build_headers(user_agent), to: HeaderBuilder, as: :build
  defdelegate get(url, headers \\ []), to: Client
  defdelegate post(url, body, headers \\ []), to: Client

  @doc "Returns the configured HTTP client module (injectable for testing)"
  def client do
    Application.get_env(:zca_ex, :http_client, ZcaEx.HTTP.AccountClient)
  end
end
