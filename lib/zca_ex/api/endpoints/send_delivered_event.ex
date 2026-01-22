defmodule ZcaEx.Api.Endpoints.SendDeliveredEvent do
  @moduledoc "Send delivered event for messages"

  use ZcaEx.Api.Factory

  alias ZcaEx.Model.Enums

  @max_messages_per_send 50

  @type message_params :: %{
          required(:msg_id) => String.t(),
          required(:cli_msg_id) => String.t(),
          required(:uid_from) => String.t(),
          required(:id_to) => String.t(),
          required(:msg_type) => String.t(),
          optional(:st) => integer(),
          optional(:at) => integer(),
          optional(:cmd) => integer(),
          optional(:ts) => String.t() | integer()
        }

  @doc """
  Send delivered event for messages.

  ## Parameters
    - `is_seen` - Whether to mark as seen (1) or not (0)
    - `messages` - A single message or list of messages
    - `thread_type` - Either `:user` or `:group` (defaults to `:user`)
    - `session` - The authenticated session
    - `credentials` - Account credentials

  ## Returns
    - `:ok` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(
          boolean(),
          message_params() | [message_params()],
          Enums.thread_type(),
          Session.t(),
          Credentials.t()
        ) ::
          :ok | {:error, ZcaEx.Error.t()}
  def call(is_seen, messages, thread_type \\ :user, session, credentials)

  def call(_is_seen, nil, _thread_type, _session, _credentials) do
    {:error,
     %ZcaEx.Error{message: "messages are missing or not in a valid array format", code: nil}}
  end

  def call(_is_seen, [], _thread_type, _session, _credentials) do
    {:error,
     %ZcaEx.Error{
       message: "messages must contain between 1 and #{@max_messages_per_send} messages",
       code: nil
     }}
  end

  def call(is_seen, messages, thread_type, session, credentials) when not is_list(messages) do
    call(is_seen, [messages], thread_type, session, credentials)
  end

  def call(_is_seen, messages, _thread_type, _session, _credentials)
      when length(messages) > @max_messages_per_send do
    {:error,
     %ZcaEx.Error{
       message: "messages must contain between 1 and #{@max_messages_per_send} messages",
       code: nil
     }}
  end

  def call(is_seen, messages, thread_type, session, credentials) do
    is_group = thread_type == :group
    first_msg = List.first(messages)
    thread_id = first_msg.id_to

    case validate_same_thread(messages, thread_id, is_group) do
      :ok ->
        do_call(is_seen, messages, thread_type, thread_id, is_group, session, credentials)

      {:error, _} = error ->
        error
    end
  end

  defp validate_same_thread(_messages, _thread_id, false), do: :ok

  defp validate_same_thread(messages, thread_id, true) do
    all_same? = Enum.all?(messages, fn msg -> msg.id_to == thread_id end)

    if all_same? do
      :ok
    else
      {:error,
       %ZcaEx.Error{message: "All messages must have the same idTo for Group thread", code: nil}}
    end
  end

  defp do_call(is_seen, messages, thread_type, thread_id, is_group, session, credentials) do
    msg_data =
      Enum.map(messages, fn msg ->
        %{
          gmi: msg.msg_id,
          cmi: msg.cli_msg_id,
          si: msg.uid_from,
          di: if(msg.id_to == session.uid, do: "0", else: msg.id_to),
          mt: msg.msg_type,
          st: get_optional_field(msg, :st, -1),
          at: get_optional_field(msg, :at, -1),
          cmd: get_optional_field(msg, :cmd, -1),
          ts: parse_ts(Map.get(msg, :ts))
        }
      end)

    msg_infos =
      %{seen: if(is_seen, do: 1, else: 0), data: msg_data}
      |> maybe_add_grid(is_group, thread_id)

    params =
      %{msgInfos: Jason.encode!(msg_infos)}
      |> maybe_add_imei(is_group, credentials.imei)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(thread_type, session)
        body = build_form_body(%{params: encrypted_params})

        case AccountClient.post(session.uid, url, body, credentials.user_agent) do
          {:ok, resp} ->
            case Response.parse(resp, session.secret_key) do
              {:ok, _data} -> :ok
              error -> error
            end

          {:error, reason} ->
            {:error, %ZcaEx.Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  defp get_optional_field(msg, key, default) do
    case Map.get(msg, key) do
      nil -> default
      0 -> 0
      val when is_integer(val) -> val
      _ -> default
    end
  end

  defp parse_ts(nil), do: -1
  defp parse_ts(0), do: 0
  defp parse_ts(val) when is_integer(val), do: val

  defp parse_ts(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> -1
    end
  end

  defp maybe_add_grid(msg_infos, true, thread_id), do: Map.put(msg_infos, :grid, thread_id)
  defp maybe_add_grid(msg_infos, false, _thread_id), do: msg_infos

  defp maybe_add_imei(params, true, imei), do: Map.put(params, :imei, imei)
  defp maybe_add_imei(params, false, _imei), do: params

  defp build_url(:user, session) do
    base = get_in(session.zpw_service_map, ["chat"]) || []
    service_url = List.first(base) || "https://chat.zalo.me"
    Url.build_for_session("#{service_url}/api/message/deliveredv2", %{nretry: 0}, session)
  end

  defp build_url(:group, session) do
    base = get_in(session.zpw_service_map, ["group"]) || []
    service_url = List.first(base) || "https://groupchat.zalo.me"
    Url.build_for_session("#{service_url}/api/group/deliveredv2", %{nretry: 0}, session)
  end
end
