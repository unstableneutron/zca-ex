defmodule ZcaEx.Api.Endpoints.SendSticker do
  @moduledoc "Send a sticker to a user or group"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type sticker_payload :: %{
          required(:id) => integer(),
          required(:cate_id) => integer(),
          required(:type) => integer()
        }

  @type send_result :: {:ok, %{msg_id: integer()}} | {:error, Error.t()}

  @doc """
  Send a sticker to a user or group.

  ## Parameters
    - `sticker` - Sticker payload with id, cate_id, and type
    - `thread_id` - The user or group ID to send to
    - `thread_type` - Either `:user` or `:group`
    - `session` - The authenticated session
    - `credentials` - Account credentials

  ## Returns
    - `{:ok, %{msg_id: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(sticker_payload(), String.t(), :user | :group, Session.t(), Credentials.t()) ::
          send_result()
  def call(sticker, thread_id, thread_type, session, credentials)

  def call(nil, _thread_id, _thread_type, _session, _credentials) do
    {:error, %Error{message: "Sticker is required", code: nil}}
  end

  def call(_sticker, thread_id, _thread_type, _session, _credentials)
      when not is_binary(thread_id) or byte_size(thread_id) == 0 do
    {:error, %Error{message: "Missing threadId", code: nil}}
  end

  def call(sticker, thread_id, thread_type, session, credentials) do
    with :ok <- validate_sticker(sticker) do
      do_call(sticker, thread_id, thread_type, session, credentials)
    end
  end

  defp validate_sticker(%{id: id, cate_id: cate_id, type: type})
       when is_integer(id) and id > 0 and is_integer(cate_id) and is_integer(type) and type > 0 do
    :ok
  end

  defp validate_sticker(%{id: id, cate_id: cate_id, type: type} = _sticker) do
    cond do
      not is_integer(id) or id <= 0 ->
        {:error, %Error{message: "Missing sticker id", code: nil}}

      not is_integer(cate_id) ->
        {:error, %Error{message: "Missing sticker cateId", code: nil}}

      not is_integer(type) or type <= 0 ->
        {:error, %Error{message: "Missing sticker type", code: nil}}

      true ->
        :ok
    end
  end

  defp validate_sticker(sticker) when is_map(sticker) do
    cond do
      not Map.has_key?(sticker, :id) ->
        {:error, %Error{message: "Missing sticker id", code: nil}}

      not Map.has_key?(sticker, :cate_id) ->
        {:error, %Error{message: "Missing sticker cateId", code: nil}}

      not Map.has_key?(sticker, :type) ->
        {:error, %Error{message: "Missing sticker type", code: nil}}

      true ->
        {:error, %Error{message: "Sticker must have id, cate_id, and type fields", code: nil}}
    end
  end

  defp validate_sticker(_) do
    {:error, %Error{message: "Sticker must have id, cate_id, and type fields", code: nil}}
  end

  defp do_call(sticker, thread_id, thread_type, session, credentials) do
    is_group = thread_type == :group

    params =
      %{
        stickerId: sticker.id,
        cateId: sticker.cate_id,
        type: sticker.type,
        clientId: System.system_time(:millisecond),
        imei: credentials.imei,
        zsource: 101
      }
      |> add_thread_param(thread_id, is_group)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(thread_type, session)
        body = build_form_body(%{params: encrypted_params})

        case AccountClient.post(session.uid, url, body, credentials.user_agent) do
          {:ok, response} ->
            Response.parse(response, session.secret_key)
            |> extract_msg_id()

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  defp add_thread_param(params, thread_id, true = _is_group) do
    Map.put(params, :grid, thread_id)
  end

  defp add_thread_param(params, thread_id, false = _is_group) do
    Map.put(params, :toid, thread_id)
  end

  defp build_url(:user, session) do
    base = get_in(session.zpw_service_map, ["chat"]) || []
    service_url = List.first(base) || "https://chat.zalo.me"
    Url.build_for_session("#{service_url}/api/message/sticker", %{nretry: 0}, session)
  end

  defp build_url(:group, session) do
    base = get_in(session.zpw_service_map, ["group"]) || []
    service_url = List.first(base) || "https://groupchat.zalo.me"
    Url.build_for_session("#{service_url}/api/group/sticker", %{nretry: 0}, session)
  end

  defp extract_msg_id({:ok, %{"msgId" => msg_id}}), do: {:ok, %{msg_id: msg_id}}
  defp extract_msg_id({:ok, data}) when is_map(data), do: {:ok, data}
  defp extract_msg_id({:error, _} = error), do: error
end
