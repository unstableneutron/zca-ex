defmodule ZcaEx.Api.Endpoints.UpdateLabels do
  @moduledoc "Update conversation labels"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Update conversation labels.

  ## Parameters
    - label_data: List of label maps
    - version: Current version number
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{label_data: list, version: integer, last_update_time: integer}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec update(list(), integer(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def update(label_data, version, session, credentials) do
    with :ok <- validate_label_data(label_data),
         :ok <- validate_version(version),
         {:ok, label_data_json} <- encode_label_data(label_data) do
      params = build_params(label_data_json, version, credentials.imei)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(session)
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

  @doc "Build URL for update labels endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session) <> "/api/convlabel/update"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), integer(), String.t()) :: map()
  def build_params(label_data_json, version, imei) do
    %{
      labelData: label_data_json,
      version: version,
      imei: imei
    }
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

  @doc "Validate label_data input"
  @spec validate_label_data(any()) :: :ok | {:error, Error.t()}
  def validate_label_data(label_data) when is_list(label_data), do: :ok

  def validate_label_data(_),
    do: {:error, Error.new(:api, "label_data must be a list", code: :invalid_input)}

  @doc "Validate version input"
  @spec validate_version(any()) :: :ok | {:error, Error.t()}
  def validate_version(version) when is_integer(version) and version >= 0, do: :ok

  def validate_version(_),
    do: {:error, Error.new(:api, "version must be a non-negative integer", code: :invalid_input)}

  defp encode_label_data(label_data) do
    case Jason.encode(label_data) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, Error.new(:api, "Failed to encode label_data: #{inspect(reason)}", code: :invalid_input)}
    end
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["label"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "label service URL not found"
    end
  end
end
