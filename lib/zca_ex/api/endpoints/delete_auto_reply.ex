defmodule ZcaEx.Api.Endpoints.DeleteAutoReply do
  @moduledoc """
  Delete an auto-reply rule.

  Note: This API is used for zBusiness accounts.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Delete an auto-reply rule.

  ## Parameters
    - id: Auto-reply rule ID (positive integer)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{item: integer(), version: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec delete(integer(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def delete(id, _session, _credentials) when not is_integer(id) or id <= 0 do
    {:error, Error.new(:api, "id must be a positive integer", code: :invalid_input)}
  end

  def delete(id, session, credentials) do
    with {:ok, service_url} <- get_service_url(session) do
      params = build_params(id, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
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
  def build_params(id, credentials) do
    %{
      cliLang: credentials.language,
      id: id
    }
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/autoreply/delete"
    Url.build_for_session(base_url, %{}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["auto_reply"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "auto_reply service URL not found", code: :service_not_found)}
    end
  end

  defp transform_response(data) when is_map(data) do
    %{
      item: data["item"] || data[:item],
      version: data["version"] || data[:version]
    }
  end
end
