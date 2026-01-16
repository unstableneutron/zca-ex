defmodule ZcaEx.Api.Endpoints.SetMute do
  @moduledoc "Set mute for a conversation"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @mute_action_mute 1
  @mute_action_unmute 3
  @mute_duration_one_hour 3600
  @mute_duration_four_hours 14400
  @mute_duration_forever -1

  @mute_type_user 1
  @mute_type_group 2

  @type mute_action :: :mute | :unmute
  @type mute_duration :: :one_hour | :four_hours | :forever | :until_8am | non_neg_integer()

  @doc """
  Set mute for a conversation.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - thread_id: ID of thread to mute
    - thread_type: :user or :group
    - opts: Options
      - `:action` - :mute (default) or :unmute
      - `:duration` - :one_hour, :four_hours, :forever (default), :until_8am, or seconds

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), String.t(), :user | :group, keyword()) ::
          {:ok, :success} | {:error, Error.t()}
  def call(session, credentials, thread_id, thread_type \\ :user, opts \\ []) do
    with :ok <- validate_thread_id(thread_id) do
      action = Keyword.get(opts, :action, :mute)
      duration_opt = Keyword.get(opts, :duration, :forever)

      params = build_params(thread_id, thread_type, action, duration_opt, credentials.imei)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
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

  @doc "Validate thread_id"
  @spec validate_thread_id(term()) :: :ok | {:error, Error.t()}
  def validate_thread_id(thread_id) when is_binary(thread_id) and byte_size(thread_id) > 0, do: :ok
  def validate_thread_id(""), do: {:error, %Error{message: "thread_id is required", code: nil}}
  def validate_thread_id(nil), do: {:error, %Error{message: "thread_id is required", code: nil}}
  def validate_thread_id(_), do: {:error, %Error{message: "thread_id must be a non-empty string", code: nil}}

  @doc "Build params for encryption"
  @spec build_params(String.t(), :user | :group, mute_action(), mute_duration(), String.t()) :: map()
  def build_params(thread_id, thread_type, action, duration_opt, imei) do
    action_value = action_to_value(action)
    duration_value = calculate_duration(action, duration_opt)
    mute_type = thread_type_to_value(thread_type)

    %{
      toid: thread_id,
      duration: duration_value,
      action: action_value,
      startTime: System.system_time(:second),
      muteType: mute_type,
      imei: imei
    }
  end

  @doc "Build URL for set mute endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session) <> "/api/social/profile/setmute"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    build_url(session)
  end

  @doc "Convert action atom to API value"
  @spec action_to_value(mute_action()) :: integer()
  def action_to_value(:mute), do: @mute_action_mute
  def action_to_value(:unmute), do: @mute_action_unmute

  @doc "Convert thread_type to API mute_type value"
  @spec thread_type_to_value(:user | :group) :: integer()
  def thread_type_to_value(:user), do: @mute_type_user
  def thread_type_to_value(:group), do: @mute_type_group

  @doc "Calculate duration based on action and duration option"
  @spec calculate_duration(mute_action(), mute_duration()) :: integer()
  def calculate_duration(:unmute, _), do: @mute_duration_forever
  def calculate_duration(:mute, :forever), do: @mute_duration_forever
  def calculate_duration(:mute, :one_hour), do: @mute_duration_one_hour
  def calculate_duration(:mute, :four_hours), do: @mute_duration_four_hours
  def calculate_duration(:mute, :until_8am), do: seconds_until_8am()
  def calculate_duration(:mute, seconds) when is_integer(seconds), do: seconds

  @doc "Calculate seconds until the next 8am"
  @spec seconds_until_8am() :: integer()
  def seconds_until_8am do
    seconds_until_8am(DateTime.utc_now())
  end

  @doc "Calculate seconds until the next 8am from a given datetime"
  @spec seconds_until_8am(DateTime.t()) :: integer()
  def seconds_until_8am(now) do
    today_8am = %{now | hour: 8, minute: 0, second: 0, microsecond: {0, 0}}

    target_8am =
      if DateTime.compare(now, today_8am) == :lt do
        today_8am
      else
        DateTime.add(today_8am, 1, :day)
      end

    DateTime.diff(target_8am, now, :second)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["profile"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for profile"
    end
  end
end
