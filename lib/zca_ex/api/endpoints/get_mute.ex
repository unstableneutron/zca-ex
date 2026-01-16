defmodule ZcaEx.Api.Endpoints.GetMute do
  @moduledoc "Get mute settings for all conversations"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type mute_entry :: %{
          id: String.t(),
          duration: integer(),
          start_time: integer(),
          system_time: integer(),
          current_time: integer(),
          mute_mode: integer()
        }

  @type mute_response :: %{
          chat_entries: [mute_entry()],
          group_chat_entries: [mute_entry()]
        }

  @doc """
  Get mute settings for all conversations.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, mute_response()}` with chat_entries and group_chat_entries on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t()) :: {:ok, mute_response()} | {:error, Error.t()}
  def call(session, credentials) do
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
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL for get mute endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :profile) <> "/api/social/profile/getmute"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :profile) <> "/api/social/profile/getmute"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t()) :: map()
  def build_params(imei) do
    %{imei: imei}
  end

  @doc "Transform API response to Elixir-style keys"
  @spec transform_response(map()) :: mute_response()
  def transform_response(data) do
    chat_entries = data["chatEntries"] || data[:chatEntries] || []
    group_chat_entries = data["groupChatEntries"] || data[:groupChatEntries] || []

    %{
      chat_entries: Enum.map(chat_entries, &transform_entry/1),
      group_chat_entries: Enum.map(group_chat_entries, &transform_entry/1)
    }
  end

  @doc "Transform a single mute entry to Elixir-style keys"
  @spec transform_entry(map()) :: mute_entry()
  def transform_entry(entry) do
    %{
      id: entry["id"] || entry[:id],
      duration: entry["duration"] || entry[:duration],
      start_time: entry["startTime"] || entry[:startTime] || entry[:start_time],
      system_time: entry["systemTime"] || entry[:systemTime] || entry[:system_time],
      current_time: entry["currentTime"] || entry[:currentTime] || entry[:current_time],
      mute_mode: entry["muteMode"] || entry[:muteMode] || entry[:mute_mode]
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
