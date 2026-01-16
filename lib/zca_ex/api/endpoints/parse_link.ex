defmodule ZcaEx.Api.Endpoints.ParseLink do
  @moduledoc """
  Parse a URL to extract metadata for link preview.

  ## Example

      ParseLink.parse("https://example.com", session, creds)
      # => {:ok, %{thumb: "...", title: "...", desc: "...", src: "...", href: "...", media: %{...}}}
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type link_data :: %{
          thumb: String.t(),
          title: String.t(),
          desc: String.t(),
          src: String.t(),
          href: String.t(),
          media: map()
        }

  @type link_metadata :: %{
          data: link_data(),
          error_maps: map()
        }

  @doc "Parse a link to extract metadata"
  @spec parse(String.t(), Session.t(), Credentials.t()) :: {:ok, link_metadata()} | {:error, Error.t()}
  def parse(link, session, credentials) do
    with :ok <- validate_link(link) do
      url = build_url(session)
      params = build_params(link, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          separator = if String.contains?(url, "?"), do: "&", else: "?"
          full_url = url <> separator <> "params=" <> URI.encode_www_form(encrypted_params)

          case AccountClient.get(credentials.imei, full_url, credentials.user_agent) do
            {:ok, response} ->
              Response.parse(response, session.secret_key)
              |> extract_data()

            {:error, reason} ->
              {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "Build the parse link URL"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base = get_in(session.zpw_service_map, ["file", Access.at(0)]) <> "/api/message/parselink"
    Url.build(base, %{}, nretry: 0, api_type: session.api_type, version: session.api_version)
  end

  @doc "Build API params"
  @spec build_params(String.t(), Credentials.t()) :: map()
  def build_params(link, credentials) do
    %{
      link: link,
      version: 1,
      imei: credentials.imei
    }
  end

  defp validate_link(link) when is_binary(link) and byte_size(link) > 0, do: :ok
  defp validate_link(_), do: {:error, %Error{message: "Missing link", code: nil}}

  defp extract_data({:ok, %{"data" => data, "error_maps" => error_maps}}) do
    {:ok,
     %{
       data: %{
         thumb: data["thumb"] || "",
         title: data["title"] || "",
         desc: data["desc"] || "",
         src: data["src"] || "",
         href: data["href"] || "",
         media: data["media"] || %{}
       },
       error_maps: error_maps || %{}
     }}
  end

  defp extract_data({:ok, %{"data" => data}}) do
    {:ok,
     %{
       data: %{
         thumb: data["thumb"] || "",
         title: data["title"] || "",
         desc: data["desc"] || "",
         src: data["src"] || "",
         href: data["href"] || "",
         media: data["media"] || %{}
       },
       error_maps: %{}
     }}
  end

  defp extract_data({:ok, data}) when is_map(data), do: {:ok, data}
  defp extract_data({:error, _} = error), do: error
end
