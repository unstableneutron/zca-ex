defmodule ZcaEx.Api.Endpoints.GetAutoReplyList do
  @moduledoc """
  Get list of auto-reply rules.

  Note: This API is used for zBusiness accounts.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get auto-reply list.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{items: list(), version: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec list(Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def list(session, credentials) do
    with {:ok, service_url} <- get_service_url(session) do
      params = build_params(credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, session, encrypted_params)

          case AccountClient.get(session.uid, url, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, data} -> {:ok, transform_response(data)}
                {:error, _} = error -> error
              end

            {:error, reason} ->
              {:error, Error.new(:network, "Request failed: #{inspect(reason)}", reason: reason)}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc false
  def build_params(credentials) do
    %{
      version: 0,
      cliLang: credentials.language
    }
  end

  @doc false
  def build_url(service_url, session, encrypted_params) do
    base_url = service_url <> "/api/autoreply/list"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["auto_reply"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "auto_reply service URL not found", code: :service_not_found)}
    end
  end

  defp transform_response(data) when is_map(data) do
    items = data["item"] || data[:item] || data["items"] || data[:items] || []

    %{
      items: items,
      version: data["version"] || data[:version]
    }
  end
end
