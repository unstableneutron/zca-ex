defmodule ZcaEx.Api.Endpoints.SendFriendRequestByPhone do
  @moduledoc """
  Send a friend request to a user by phone number.

  This is a convenience endpoint that combines FindUser, GetSentFriendRequest,
  and SendFriendRequest. It handles several scenarios:

  1. **User found with userId** - Sends friend request directly
  2. **User found but userId hidden** - Checks pending requests for userId
  3. **Request already pending** - Returns pending status with user info
  4. **User not found** - Returns error

  ## Privacy Limitations

  Some Zalo users have privacy settings that hide their user ID. `FindUser`
  returns profile info (avatar, name, globalId) but with empty `uid`. However,
  if you've previously sent a request, `GetSentFriendRequest` will have the
  actual userId.
  """

  alias ZcaEx.Api.Endpoints.{FindUser, SendFriendRequest, GetSentFriendRequest}
  alias ZcaEx.Account.{Session, Credentials}
  alias ZcaEx.Error

  @type user_info :: %{
          uid: String.t(),
          global_id: String.t(),
          zalo_name: String.t() | nil,
          display_name: String.t() | nil,
          avatar: String.t() | nil,
          status: String.t() | nil
        }

  @type send_result ::
          {:ok, %{status: :sent, user: user_info(), result: map()}}
          | {:ok, %{status: :already_pending, user: user_info(), sent_at: integer() | nil}}
          | {:ok, %{status: :already_friends, user: user_info()}}
          | {:ok, %{status: :accepted_mutual, user: user_info()}}
          | {:error, Error.t()}

  @type lookup_result ::
          {:ok, %{user: user_info(), can_send_request: boolean(), pending_since: integer() | nil}}
          | {:error, Error.t()}

  @doc """
  Send a friend request by phone number.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - phone_number: Phone number to search for
    - opts: Options
      - `:message` - Message to send with the request (optional, defaults to "")

  ## Returns
    - `{:ok, %{status: :sent, user: user_info, result: map()}}` - Request sent
    - `{:ok, %{status: :already_pending, user: user_info, sent_at: timestamp}}` - Already pending
    - `{:ok, %{status: :already_friends, user: user_info}}` - Already friends (code 225)
    - `{:ok, %{status: :accepted_mutual, user: user_info}}` - Mutual request accepted (code 222)
    - `{:error, Error.t()}` on failure

  ## Error Codes
    - `:user_not_found` - No user found with the given phone number
    - `:user_id_hidden` - User ID hidden and no pending request to get it from
    - `215` - User may have blocked you
  """
  @spec call(Session.t(), Credentials.t(), String.t(), keyword()) :: send_result()
  def call(session, credentials, phone_number, opts \\ []) do
    with {:ok, user} <- find_user(session, credentials, phone_number),
         {:ok, user, status} <- resolve_user_id(user, session, credentials),
         {:ok, result} <- maybe_send_request(status, user, session, credentials, opts) do
      {:ok, result}
    end
  end

  @doc """
  Find user and return their info with resolved userId if possible.
  Checks both FindUser and pending requests to get the most complete info.

  ## Returns
    - `{:ok, %{user: user_info, can_send_request: boolean, pending_since: timestamp | nil}}`
    - `{:error, Error.t()}` on failure
  """
  @spec lookup(Session.t(), Credentials.t(), String.t()) :: lookup_result()
  def lookup(session, credentials, phone_number) do
    with {:ok, user} <- find_user(session, credentials, phone_number) do
      # Short-circuit if no global_id to search pending requests
      if user.global_id == "" do
        {:ok,
         %{
           user: user,
           can_send_request: user.uid != "" and user.uid != nil,
           pending_since: nil
         }}
      else
        case check_pending_requests(user.global_id, session, credentials) do
          {:ok, {uid, pending_info}} ->
            merged_user = merge_user_info(user, uid, pending_info)

            {:ok,
             %{
               user: merged_user,
               can_send_request: merged_user.uid != "",
               pending_since: get_in(pending_info, ["fReqInfo", "time"])
             }}

          :not_pending ->
            {:ok,
             %{
               user: user,
               can_send_request: user.uid != "" and user.uid != nil,
               pending_since: nil
             }}

          {:error, _} = error ->
            error
        end
      end
    end
  end

  # --- Private functions ---

  defp find_user(session, credentials, phone_number) do
    case FindUser.call(session, credentials, phone_number) do
      {:ok, user} ->
        {:ok, normalize_user(user)}

      {:error, %Error{code: 216}} ->
        # Mask phone number in error message for privacy
        masked = mask_phone(phone_number)

        {:error,
         %Error{code: :user_not_found, message: "No user found with phone number: #{masked}"}}

      {:error, _} = error ->
        error
    end
  end

  defp mask_phone(phone) when is_binary(phone) and byte_size(phone) > 4 do
    visible = String.slice(phone, -4, 4)
    "****#{visible}"
  end

  defp mask_phone(_phone), do: "****"

  defp normalize_user(user) do
    %{
      uid: user.uid || "",
      global_id: user.global_id || "",
      zalo_name: user.zalo_name,
      display_name: user.display_name,
      avatar: user.avatar,
      status: user.status
    }
  end

  defp resolve_user_id(user, session, credentials) do
    cond do
      # User ID available from FindUser
      user.uid != "" ->
        {:ok, user, :ready}

      # Check pending requests for userId
      user.global_id != "" ->
        case check_pending_requests(user.global_id, session, credentials) do
          {:ok, {uid, pending_info}} ->
            merged = merge_user_info(user, uid, pending_info)
            sent_at = get_in(pending_info, ["fReqInfo", "time"])
            {:ok, merged, {:already_pending, sent_at}}

          :not_pending ->
            # Don't expose globalId in error message for privacy
            name = user.zalo_name || user.display_name || "(unknown)"

            {:error,
             %Error{
               code: :user_id_hidden,
               message: "User '#{name}' found but ID is hidden due to privacy settings"
             }}

          {:error, _} = error ->
            error
        end

      true ->
        {:error, %Error{code: :user_id_hidden, message: "No user ID or global ID available"}}
    end
  end

  defp check_pending_requests(global_id, session, credentials) do
    case GetSentFriendRequest.list(session, credentials) do
      {:ok, pending_map} when is_map(pending_map) ->
        # Find by globalId, return both the map key (userId) and info
        case Enum.find(pending_map, fn {_uid, info} ->
               info["globalId"] == global_id
             end) do
          {uid, info} -> {:ok, {uid, info}}
          nil -> :not_pending
        end

      {:error, %Error{code: 112}} ->
        # No pending requests exist
        :not_pending

      {:error, _} = error ->
        # Propagate real errors (network, auth, etc.)
        error
    end
  end

  defp merge_user_info(user, uid_from_key, pending_info) do
    %{
      user
      | uid: uid_from_key || pending_info["userId"] || user.uid,
        zalo_name: pending_info["zaloName"] || user.zalo_name,
        display_name: pending_info["displayName"] || user.display_name,
        avatar: pending_info["avatar"] || user.avatar
    }
  end

  defp maybe_send_request({:already_pending, sent_at}, user, _session, _credentials, _opts) do
    {:ok, %{user: user, status: :already_pending, sent_at: sent_at}}
  end

  defp maybe_send_request(:ready, user, session, credentials, opts) do
    case SendFriendRequest.call(session, credentials, user.uid, opts) do
      {:ok, result} ->
        {:ok, %{user: user, result: result, status: :sent}}

      {:error, %Error{code: 225}} ->
        {:ok, %{user: user, status: :already_friends}}

      {:error, %Error{code: 222}} ->
        # Mutual request - treated as acceptance
        {:ok, %{user: user, status: :accepted_mutual}}

      {:error, _} = error ->
        error
    end
  end

  # --- Test helpers ---

  @doc false
  def extract_user_id_for_test(user) do
    if user.uid != "" and user.uid != nil do
      {:ok, user.uid}
    else
      {:error, %Error{code: :user_id_hidden, message: "User ID hidden"}}
    end
  end
end
