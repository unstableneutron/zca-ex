defmodule ZcaEx.Api.Endpoints.GetAutoDeleteChat do
  @moduledoc "Get auto-delete chat settings for all conversations"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type auto_delete_entry :: %{
          dest_id: String.t(),
          is_group: boolean(),
          ttl: integer(),
          created_at: integer()
        }

  @type auto_delete_response :: %{
          convers: [auto_delete_entry()]
        }

  @doc """
  Get auto-delete chat settings for all conversations.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, auto_delete_response()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t()) :: {:ok, auto_delete_response()} | {:error, Error.t()}
  def call(session, credentials) do
    url = build_url(session)

    case AccountClient.get(session.uid, url, credentials.user_agent) do
      {:ok, response} ->
        with {:ok, data} <- Response.parse(response, session.secret_key) do
          {:ok, transform_response(data)}
        end

      {:error, reason} ->
        {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
    end
  end

  @doc "Build params for get auto-delete chat endpoint"
  @spec build_params() :: map()
  def build_params, do: %{}

  @doc "Build base URL for get auto-delete chat endpoint"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    get_service_url(session, :conversation) <> "/api/conv/autodelete/getConvers"
  end

  @doc "Build URL for get auto-delete chat endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = build_base_url(session)
    Url.build_for_session(base_url, build_params(), session)
  end

  @doc "Transform response to snake_case keys"
  @spec transform_response(map()) :: auto_delete_response()
  def transform_response(data) do
    convers = Map.get(data, "convers") || Map.get(data, :convers) || []

    %{
      convers: Enum.map(convers, &transform_entry/1)
    }
  end

  @doc "Transform a single auto-delete entry to snake_case keys"
  @spec transform_entry(map()) :: auto_delete_entry()
  def transform_entry(entry) do
    %{
      dest_id: Map.get(entry, "destId") || Map.get(entry, :destId),
      is_group: to_boolean(Map.get(entry, "isGroup") || Map.get(entry, :isGroup)),
      ttl: Map.get(entry, "ttl") || Map.get(entry, :ttl),
      created_at: Map.get(entry, "createdAt") || Map.get(entry, :createdAt)
    }
  end

  defp to_boolean(true), do: true
  defp to_boolean(false), do: false
  defp to_boolean(1), do: true
  defp to_boolean(0), do: false
  defp to_boolean(_), do: false

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
