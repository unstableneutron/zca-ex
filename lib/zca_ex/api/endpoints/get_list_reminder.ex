defmodule ZcaEx.Api.Endpoints.GetListReminder do
  @moduledoc "Get list of reminders for a user or group thread"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @default_page 1
  @default_count 20

  @type thread_type :: :user | :group

  @doc """
  Get list of reminders for a thread.

  ## Parameters
    - thread_id: User ID or Group ID
    - thread_type: `:user` or `:group`
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Options
      - `:page` - Page number (default: 1)
      - `:count` - Number of items per page (default: 20)

  ## Returns
    - `{:ok, [map()]}` list of reminders on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), thread_type(), Session.t(), Credentials.t(), keyword()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def call(thread_id, thread_type, session, credentials, opts \\ [])
      when thread_type in [:user, :group] do
    page = Keyword.get(opts, :page, @default_page)
    count = Keyword.get(opts, :count, @default_count)

    case build_params(thread_id, thread_type, page, count, credentials.imei) do
      {:ok, params} ->
        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(session, thread_type, encrypted_params)

            case AccountClient.get(session.uid, url, credentials.user_agent) do
              {:ok, response} ->
                case Response.parse(response, session.secret_key) do
                  {:ok, data} -> parse_data_field(data)
                  {:error, _} = error -> error
                end

              {:error, reason} ->
                {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
            end

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL with encrypted params based on thread type"
  @spec build_url(Session.t(), thread_type(), String.t()) :: String.t()
  def build_url(session, thread_type, encrypted_params) do
    base_url = get_service_url(session, :group_board) <> get_path(thread_type)
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t(), thread_type()) :: String.t()
  def build_base_url(session, thread_type) do
    base_url = get_service_url(session, :group_board) <> get_path(thread_type)
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Get API path based on thread type"
  @spec get_path(thread_type()) :: String.t()
  def get_path(:user), do: "/api/board/oneone/list"
  def get_path(:group), do: "/api/board/listReminder"

  @doc "Build params for encryption"
  @spec build_params(String.t(), thread_type(), integer(), integer(), String.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def build_params(thread_id, :user, page, count, _imei) do
    object_data = %{
      uid: thread_id,
      board_type: 1,
      page: page,
      count: count,
      last_id: 0,
      last_type: 0
    }

    case Jason.encode(object_data) do
      {:ok, json} ->
        {:ok, %{objectData: json}}

      {:error, reason} ->
        {:error, %Error{message: "Failed to encode params: #{inspect(reason)}", code: nil}}
    end
  end

  def build_params(thread_id, :group, page, count, imei) do
    object_data = %{
      group_id: thread_id,
      board_type: 1,
      page: page,
      count: count,
      last_id: 0,
      last_type: 0
    }

    case Jason.encode(object_data) do
      {:ok, json} ->
        {:ok, %{objectData: json, imei: imei}}

      {:error, reason} ->
        {:error, %Error{message: "Failed to encode params: #{inspect(reason)}", code: nil}}
    end
  end

  defp parse_data_field(data) when is_map(data) do
    case Map.get(data, "data") || Map.get(data, :data) do
      json_string when is_binary(json_string) ->
        case Jason.decode(json_string) do
          {:ok, parsed} ->
            {:ok, parsed}

          {:error, reason} ->
            {:error, %Error{message: "Failed to parse data field: #{inspect(reason)}", code: nil}}
        end

      list when is_list(list) ->
        {:ok, list}

      nil ->
        {:ok, data}

      other ->
        {:ok, other}
    end
  end

  defp parse_data_field(data), do: {:ok, data}

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
