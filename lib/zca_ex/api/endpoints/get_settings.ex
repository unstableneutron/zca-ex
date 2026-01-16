defmodule ZcaEx.Api.Endpoints.GetSettings do
  @moduledoc "Get account settings"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @settings_url "https://wpa.chat.zalo.me/api/setting/me"

  @type settings_response :: %{
          view_birthday: integer() | nil,
          show_online_status: integer() | nil,
          display_seen_status: integer() | nil,
          receive_message: integer() | nil,
          accept_call: integer() | nil,
          add_friend_via_phone: integer() | nil,
          add_friend_via_qr: integer() | nil,
          add_friend_via_group: integer() | nil,
          add_friend_via_contact: integer() | nil,
          display_on_recommend_friend: integer() | nil,
          archived_chat: integer() | nil,
          quick_message: integer() | nil,
          raw: map()
        }

  @doc """
  Get account settings.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, settings_response()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t()) ::
          {:ok, settings_response()} | {:error, Error.t()}
  def call(session, credentials) do
    params = %{}

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

  @doc "Build URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    Url.build_for_session(@settings_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    Url.build_for_session(@settings_url, %{}, session)
  end

  @doc "Transform raw API response to snake_case keys"
  @spec transform_response(map()) :: settings_response()
  def transform_response(data) do
    %{
      view_birthday: get_setting(data, "view_birthday"),
      show_online_status: get_setting(data, "show_online_status"),
      display_seen_status: get_setting(data, "display_seen_status"),
      receive_message: get_setting(data, "receive_message"),
      accept_call: get_setting(data, "accept_stranger_call"),
      add_friend_via_phone: get_setting(data, "add_friend_via_phone"),
      add_friend_via_qr: get_setting(data, "add_friend_via_qr"),
      add_friend_via_group: get_setting(data, "add_friend_via_group"),
      add_friend_via_contact: get_setting(data, "add_friend_via_contact"),
      display_on_recommend_friend: get_setting(data, "display_on_recommend_friend"),
      archived_chat: get_setting(data, "archivedChatStatus"),
      quick_message: get_setting(data, "quickMessageStatus"),
      raw: data
    }
  end

  defp get_setting(data, key) do
    atom_key = String.to_existing_atom(key)
    data[key] || data[atom_key]
  rescue
    ArgumentError -> data[key]
  end
end
