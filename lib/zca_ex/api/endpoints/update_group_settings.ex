defmodule ZcaEx.Api.Endpoints.UpdateGroupSettings do
  @moduledoc """
  Update group settings.

  ## Options
    - block_name: Disallow members to change group name/avatar
    - sign_admin_msg: Highlight messages from owner/admins
    - set_topic_only: Don't pin messages, notes, polls to top
    - enable_msg_history: Allow new members to read recent messages
    - join_appr: Membership approval required
    - lock_create_post: Disallow members to create notes & reminders
    - lock_create_poll: Disallow members to create polls
    - lock_send_msg: Disallow members to send messages
    - lock_view_member: Disallow members to view full member list
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type settings :: %{
          optional(:block_name) => boolean(),
          optional(:sign_admin_msg) => boolean(),
          optional(:set_topic_only) => boolean(),
          optional(:enable_msg_history) => boolean(),
          optional(:join_appr) => boolean(),
          optional(:lock_create_post) => boolean(),
          optional(:lock_create_poll) => boolean(),
          optional(:lock_send_msg) => boolean(),
          optional(:lock_view_member) => boolean()
        }

  @doc """
  Update group settings.

  ## Parameters
    - settings: Map of boolean settings to update
    - group_id: The group ID to update
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{}}` on success
    - `{:error, Error.t()}` on failure

  ## Note
    Zalo might return error code 166 if you don't have permission to change settings.
  """
  @spec call(settings(), String.t(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(settings, group_id, session, credentials) do
    params = build_params(settings, group_id, credentials)

    with {:ok, encrypted_params} <- encrypt_params(session.secret_key, params),
         {:ok, service_url} <- get_service_url(session, :group) do
      url = build_url(service_url, encrypted_params, session)

      case AccountClient.get(session.uid, url, credentials.user_agent) do
        {:ok, response} ->
          Response.parse(response, session.secret_key)

        {:error, reason} ->
          {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
      end
    end
  end

  @doc "Build params for encryption"
  @spec build_params(settings(), String.t(), Credentials.t()) :: map()
  def build_params(settings, group_id, credentials) do
    %{
      blockName: bool_to_int(settings[:block_name]),
      signAdminMsg: bool_to_int(settings[:sign_admin_msg]),
      setTopicOnly: bool_to_int(settings[:set_topic_only]),
      enableMsgHistory: bool_to_int(settings[:enable_msg_history]),
      joinAppr: bool_to_int(settings[:join_appr]),
      lockCreatePost: bool_to_int(settings[:lock_create_post]),
      lockCreatePoll: bool_to_int(settings[:lock_create_poll]),
      lockSendMsg: bool_to_int(settings[:lock_send_msg]),
      lockViewMember: bool_to_int(settings[:lock_view_member]),
      bannFeature: 0,
      dirtyMedia: 0,
      banDuration: 0,
      blocked_members: [],
      grid: group_id,
      imei: credentials.imei
    }
  end

  @doc "Build URL for update group settings endpoint (GET with params in query)"
  @spec build_url(String.t(), String.t(), Session.t()) :: String.t()
  def build_url(service_url, encrypted_params, session) do
    base_url = service_url <> "/api/group/setting/update"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  defp bool_to_int(true), do: 1
  defp bool_to_int(_), do: 0

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, %Error{message: "Service URL not found for #{service}", code: nil}}
    end
  end
end
