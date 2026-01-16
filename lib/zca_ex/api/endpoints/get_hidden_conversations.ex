defmodule ZcaEx.Api.Endpoints.GetHiddenConversations do
  @moduledoc "Get list of hidden conversations"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type hidden_thread :: %{
          thread_id: String.t(),
          is_group: boolean()
        }

  @type hidden_response :: %{
          pin: String.t(),
          threads: [hidden_thread()]
        }

  @doc """
  Get all hidden conversations.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{pin: String.t(), threads: [hidden_thread()]}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t()) :: {:ok, hidden_response()} | {:error, Error.t()}
  def call(session, credentials) do
    params = build_params(credentials.imei)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
          {:ok, response} ->
            with {:ok, data} <- Response.parse(response, session.secret_key) do
              {:ok, transform_response(data)}
            end

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL for get hidden conversations endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :conversation) <> "/api/hiddenconvers/get-all"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :conversation) <> "/api/hiddenconvers/get-all"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t()) :: map()
  def build_params(imei) do
    %{imei: imei}
  end

  @doc "Transform API response to structured format"
  @spec transform_response(map()) :: hidden_response()
  def transform_response(data) do
    %{
      pin: Map.get(data, "pin") || Map.get(data, :pin) || "",
      threads: transform_threads(Map.get(data, "threads") || Map.get(data, :threads) || [])
    }
  end

  @doc "Transform list of thread objects"
  @spec transform_threads([map()]) :: [hidden_thread()]
  def transform_threads(threads) when is_list(threads) do
    Enum.map(threads, &transform_thread/1)
  end

  @doc "Transform a single thread object (converts is_group: 0/1 to boolean)"
  @spec transform_thread(map()) :: hidden_thread()
  def transform_thread(thread) do
    %{
      thread_id: Map.get(thread, "thread_id") || Map.get(thread, :thread_id) || "",
      is_group: (Map.get(thread, "is_group") || Map.get(thread, :is_group) || 0) == 1
    }
  end

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
