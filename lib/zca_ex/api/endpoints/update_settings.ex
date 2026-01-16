defmodule ZcaEx.Api.Endpoints.UpdateSettings do
  @moduledoc "Update account settings"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @settings_url "https://wpa.chat.zalo.me/api/setting/update"

  @type setting_type ::
          :view_birthday
          | :show_online_status
          | :display_seen_status
          | :receive_message
          | :accept_call
          | :add_friend_via_phone
          | :add_friend_via_qr
          | :add_friend_via_group
          | :add_friend_via_contact
          | :display_on_recommend_friend
          | :archived_chat
          | :quick_message

  @setting_keys %{
    view_birthday: "view_birthday",
    show_online_status: "show_online_status",
    display_seen_status: "display_seen_status",
    receive_message: "receive_message",
    accept_call: "accept_stranger_call",
    add_friend_via_phone: "add_friend_via_phone",
    add_friend_via_qr: "add_friend_via_qr",
    add_friend_via_group: "add_friend_via_group",
    add_friend_via_contact: "add_friend_via_contact",
    display_on_recommend_friend: "display_on_recommend_friend",
    archived_chat: "archivedChatStatus",
    quick_message: "quickMessageStatus"
  }

  @doc """
  Update an account setting.

  ## Setting Types and Values
    - `:view_birthday` - 0: hide, 1: show full day/month/year, 2: show day/month
    - `:show_online_status` - 0: hide, 1: show
    - `:display_seen_status` - 0: hide, 1: show
    - `:receive_message` - 1: everyone, 2: only friends
    - `:accept_call` - 2: only friends, 3: everyone, 4: friends and contacted
    - `:add_friend_via_phone` - 0: disable, 1: enable
    - `:add_friend_via_qr` - 0: disable, 1: enable
    - `:add_friend_via_group` - 0: disable, 1: enable
    - `:add_friend_via_contact` - 0: disable, 1: enable
    - `:display_on_recommend_friend` - 0: disable, 1: enable
    - `:archived_chat` - 0: disable, 1: enable
    - `:quick_message` - 0: disable, 1: enable

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - setting_type: Setting to update
    - value: New value

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), setting_type(), integer()) ::
          {:ok, :success} | {:error, Error.t()}
  def call(session, credentials, setting_type, value) do
    with :ok <- validate_setting_type(setting_type) do
      params = build_params(setting_type, value)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(session, encrypted_params)

          case AccountClient.get(session.uid, url, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, _data} -> {:ok, :success}
                {:error, _} = error -> error
              end

            {:error, reason} ->
              {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "Validate setting type"
  @spec validate_setting_type(term()) :: :ok | {:error, Error.t()}
  def validate_setting_type(type) when is_map_key(@setting_keys, type), do: :ok
  def validate_setting_type(_), do: {:error, %Error{message: "Invalid setting type", code: nil}}

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

  @doc "Build params for setting update"
  @spec build_params(setting_type(), integer()) :: map()
  def build_params(setting_type, value) do
    key = Map.get(@setting_keys, setting_type)
    %{key => value}
  end

  @doc "Get the API key for a setting type"
  @spec setting_key(setting_type()) :: String.t()
  def setting_key(type), do: Map.get(@setting_keys, type)

  @doc "Get all valid setting types"
  @spec setting_types() :: [setting_type()]
  def setting_types, do: Map.keys(@setting_keys)
end
