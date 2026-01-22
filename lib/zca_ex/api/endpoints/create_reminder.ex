defmodule ZcaEx.Api.Endpoints.CreateReminder do
  @moduledoc "Create a reminder in a user or group thread"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type thread_type :: :user | :group

  @doc """
  Create a reminder in a thread.

  ## Parameters
    - thread_id: User ID or Group ID
    - title: Reminder title
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Options
      - `:thread_type` - `:user` (default) or `:group`
      - `:emoji` - Emoji for reminder (default: "⏰")
      - `:start_time` - Unix timestamp in ms (default: now)
      - `:repeat` - 0=None, 1=Daily, 2=Weekly, 3=Monthly (default: 0)

  ## Returns
    - `{:ok, map()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), String.t(), Session.t(), Credentials.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(thread_id, title, session, credentials, opts \\ []) do
    thread_type = Keyword.get(opts, :thread_type, :user)

    with :ok <- validate_thread_type(thread_type),
         {:ok, params} <- build_params(thread_id, title, session, credentials, opts) do
      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(session, thread_type)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
            {:ok, response} ->
              Response.parse(response, session.secret_key)

            {:error, reason} ->
              {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "Validate thread_type"
  @spec validate_thread_type(term()) :: :ok | {:error, Error.t()}
  def validate_thread_type(:user), do: :ok
  def validate_thread_type(:group), do: :ok

  def validate_thread_type(_),
    do: {:error, %Error{message: "thread_type must be :user or :group", code: nil}}

  @doc "Build URL for create reminder endpoint"
  @spec build_url(Session.t(), thread_type()) :: String.t()
  def build_url(session, thread_type) do
    path =
      case thread_type do
        :user -> "/api/board/oneone/create"
        :group -> "/api/board/topic/createv2"
      end

    base_url = get_service_url(session, :group_board) <> path
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t(), Session.t(), Credentials.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def build_params(thread_id, title, session, credentials, opts) do
    thread_type = Keyword.get(opts, :thread_type, :user)
    emoji = Keyword.get(opts, :emoji, "⏰")
    start_time = Keyword.get(opts, :start_time, System.system_time(:millisecond))
    repeat = Keyword.get(opts, :repeat, 0)

    case thread_type do
      :user ->
        object_data = %{
          toUid: thread_id,
          type: 0,
          color: -16_245_706,
          emoji: emoji,
          startTime: start_time,
          duration: -1,
          params: %{title: title},
          needPin: false,
          repeat: repeat,
          creatorUid: session.uid,
          src: 1
        }

        case Jason.encode(object_data) do
          {:ok, json} ->
            {:ok, %{objectData: json, imei: credentials.imei}}

          {:error, reason} ->
            {:error, %Error{message: "Failed to encode params: #{inspect(reason)}", code: nil}}
        end

      :group ->
        case Jason.encode(%{title: title}) do
          {:ok, params_json} ->
            {:ok,
             %{
               grid: thread_id,
               type: 0,
               color: -16_245_706,
               emoji: emoji,
               startTime: start_time,
               duration: -1,
               params: params_json,
               repeat: repeat,
               src: 1,
               imei: credentials.imei,
               pinAct: 0
             }}

          {:error, reason} ->
            {:error, %Error{message: "Failed to encode params: #{inspect(reason)}", code: nil}}
        end
    end
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
