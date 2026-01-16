defmodule ZcaEx.HTTP.URL do
  @moduledoc "URL building utilities"

  @spec build(String.t(), map(), keyword()) :: String.t()
  def build(base_url, params \\ %{}, opts \\ []) do
    api_version = Keyword.get(opts, :api_version, true)
    api_type = Keyword.get(opts, :api_type, 30)
    version = Keyword.get(opts, :version, 645)

    uri = URI.parse(base_url)

    existing_params = URI.decode_query(uri.query || "")

    params =
      params
      |> Enum.into(%{})
      |> Map.merge(existing_params)

    params =
      if api_version do
        params
        |> Map.put_new("zpw_ver", to_string(version))
        |> Map.put_new("zpw_type", to_string(api_type))
      else
        params
      end

    query = URI.encode_query(params)

    %{uri | query: query}
    |> URI.to_string()
  end
end
