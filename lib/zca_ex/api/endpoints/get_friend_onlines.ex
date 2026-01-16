defmodule ZcaEx.Api.Endpoints.GetFriendOnlines do
  @moduledoc "Get online status of friends"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get online status of friends.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{onlines: list}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec list(Session.t(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def list(session, credentials) do
    params = build_params(credentials.imei)

    with {:ok, base_url} <- get_service_url(session),
         {:ok, encrypted_params} <- encrypt_params(session.secret_key, params) do
      url = build_url(base_url, encrypted_params, session)

      case AccountClient.get(session.uid, url, credentials.user_agent) do
        {:ok, response} ->
          case Response.parse(response, session.secret_key) do
            {:ok, data} -> {:ok, transform_response(data)}
            {:error, _} = error -> error
          end

        {:error, reason} ->
          {:error, Error.new(:network, "Request failed: #{inspect(reason)}", reason: reason)}
      end
    end
  end

  @doc "Build URL for get friend onlines endpoint with encrypted params"
  @spec build_url(String.t(), String.t(), Session.t()) :: String.t()
  def build_url(base_url, encrypted_params, session) do
    url = base_url <> "/api/social/friend/onlines"
    Url.build_for_session(url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, base_url} ->
        url = base_url <> "/api/social/friend/onlines"
        {:ok, Url.build_for_session(url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params(String.t()) :: map()
  def build_params(imei) do
    %{imei: imei}
  end

  @doc "Transform response data"
  @spec transform_response(map()) :: map()
  def transform_response(data) when is_map(data) do
    onlines_raw = data["onlines"] || data[:onlines] || []

    onlines =
      case onlines_raw do
        list when is_list(list) ->
          Enum.map(list, &parse_online_entry/1)

        _ ->
          []
      end

    %{onlines: onlines}
  end

  defp parse_online_entry(entry) when is_map(entry) do
    status_raw = entry["status"] || entry[:status]

    status =
      case status_raw do
        str when is_binary(str) ->
          case Jason.decode(str) do
            {:ok, parsed} -> parsed
            {:error, _} -> status_raw
          end

        other ->
          other
      end

    entry
    |> Map.put("status", status)
    |> Map.delete(:status)
  end

  defp parse_online_entry(entry), do: entry

  @spec get_service_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["profile"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "profile service URL not found", code: :service_not_found)}
    end
  end
end
