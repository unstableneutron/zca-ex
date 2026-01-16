defmodule ZcaEx.Api.Endpoints.GetLabels do
  @moduledoc "Get conversation labels"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get all conversation labels.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{label_data: list, version: integer, last_update_time: integer}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec get(Session.t(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(session, credentials) do
    params = build_params(credentials.imei)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

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

  @doc "Build URL for get labels endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session) <> "/api/convlabel/get"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session) <> "/api/convlabel/get"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t()) :: map()
  def build_params(imei) do
    %{imei: imei}
  end

  @doc "Transform response data"
  @spec transform_response(map()) :: map()
  def transform_response(data) when is_map(data) do
    label_data_raw =
      data["labelData"] || data[:labelData] || data["label_data"] || data[:label_data] || "[]"

    label_data =
      case label_data_raw do
        str when is_binary(str) ->
          case Jason.decode(str) do
            {:ok, list} -> list
            {:error, _} -> []
          end

        list when is_list(list) ->
          list

        _ ->
          []
      end

    %{
      label_data: label_data,
      version: data["version"] || data[:version],
      last_update_time:
        data["lastUpdateTime"] || data[:lastUpdateTime] || data["last_update_time"] ||
          data[:last_update_time]
    }
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["label"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "label service URL not found"
    end
  end
end
