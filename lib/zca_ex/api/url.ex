defmodule ZcaEx.Api.Url do
  @moduledoc "URL building utilities for Zalo API"

  @default_api_type 30
  @default_api_version 645

  @doc """
  Build URL with query params, handling nretry and api version.
  Matches JS makeURL behavior.

  ## Options
    - `:api_version` - whether to add zpw_ver and zpw_type (default: true)
    - `:api_type` - the zpw_type value (default: 30)
    - `:version` - the zpw_ver value (default: 645)
    - `:nretry` - retry count to append (default: nil)
  """
  @spec build(String.t(), map(), keyword()) :: String.t()
  def build(base_url, params \\ %{}, opts \\ []) do
    api_version = Keyword.get(opts, :api_version, true)
    api_type = Keyword.get(opts, :api_type, @default_api_type)
    version = Keyword.get(opts, :version, @default_api_version)
    nretry = Keyword.get(opts, :nretry)

    uri = URI.parse(base_url)
    existing_params = URI.decode_query(uri.query || "")

    params =
      existing_params
      |> Map.merge(stringify_keys(params))

    params =
      if api_version do
        params
        |> Map.put_new("zpw_ver", to_string(version))
        |> Map.put_new("zpw_type", to_string(api_type))
      else
        params
      end

    params =
      if nretry && nretry > 0 do
        Map.put(params, "nretry", to_string(nretry))
      else
        params
      end

    query = URI.encode_query(params)

    %{uri | query: query}
    |> URI.to_string()
  end

  @doc """
  Build URL for a specific session, using session's api_type and api_version.
  """
  @spec build_for_session(String.t(), map(), ZcaEx.Account.Session.t(), keyword()) :: String.t()
  def build_for_session(base_url, params, session, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:api_type, session.api_type)
      |> Keyword.put_new(:version, session.api_version)

    build(base_url, params, opts)
  end

  @doc """
  Append nretry param to an existing URL.
  """
  @spec with_retry(String.t(), non_neg_integer()) :: String.t()
  def with_retry(url, retry_count) when retry_count > 0 do
    uri = URI.parse(url)
    params = URI.decode_query(uri.query || "")
    params = Map.put(params, "nretry", to_string(retry_count))
    query = URI.encode_query(params)

    %{uri | query: query}
    |> URI.to_string()
  end

  def with_retry(url, _retry_count), do: url

  defp stringify_keys(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {to_string(k), to_string(v)} end)
  end
end
