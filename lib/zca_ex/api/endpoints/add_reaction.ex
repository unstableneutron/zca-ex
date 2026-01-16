defmodule ZcaEx.Api.Endpoints.AddReaction do
  @moduledoc "Add reaction to a message"

  use ZcaEx.Api.Factory

  alias ZcaEx.Model.Enums

  @type custom_reaction :: %{
          r_type: integer(),
          source: integer(),
          icon: String.t()
        }

  @type reaction_target :: %{
          msg_id: String.t(),
          cli_msg_id: String.t(),
          thread_id: String.t(),
          thread_type: Enums.thread_type()
        }

  @doc """
  Add a reaction to a message.

  ## Parameters
    - `reaction` - Either a standard reaction atom or a custom reaction map
    - `target` - Target message info including msg_id, cli_msg_id, thread_id, thread_type
    - `session` - The authenticated session
    - `credentials` - Account credentials

  ## Returns
    - `{:ok, %{msg_ids: [integer()]}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Enums.reaction() | custom_reaction(), reaction_target(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, ZcaEx.Error.t()}
  def call(reaction, target, session, credentials) do
    {r_type, source, icon} = get_reaction_info(reaction)

    message_payload = %{
      rMsg: [
        %{
          gMsgID: parse_int(target.msg_id),
          cMsgID: parse_int(target.cli_msg_id),
          msgType: 1
        }
      ],
      rIcon: icon,
      rType: r_type,
      source: source
    }

    with {:ok, message_json} <- Jason.encode(message_payload) do
      params =
        %{
          react_list: [
            %{
              message: message_json,
              clientId: System.system_time(:millisecond)
            }
          ]
        }
        |> add_thread_params(target, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(target.thread_type, session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(credentials.imei, url, body, credentials.user_agent) do
            {:ok, resp} ->
              Response.parse(resp, session.secret_key)
              |> transform_response()

            {:error, reason} ->
              {:error, %ZcaEx.Error{message: "Request failed: #{inspect(reason)}", code: nil}}
          end

        {:error, _} = error ->
          error
      end
    else
      {:error, reason} ->
        {:error, %ZcaEx.Error{message: "Failed to encode message payload: #{inspect(reason)}", code: nil}}
    end
  end

  defp get_reaction_info(%{r_type: r_type, source: source, icon: icon}) do
    {r_type, source, icon}
  end

  defp get_reaction_info(reaction) when is_atom(reaction) do
    {r_type, source} = Enums.reaction_type(reaction)
    icon = Enums.reaction_icon(reaction)
    {r_type, source, icon}
  end

  defp add_thread_params(params, %{thread_type: :user, thread_id: thread_id}, _credentials) do
    Map.put(params, :toid, thread_id)
  end

  defp add_thread_params(params, %{thread_type: :group, thread_id: thread_id}, credentials) do
    params
    |> Map.put(:grid, thread_id)
    |> Map.put(:imei, credentials.imei)
  end

  defp build_url(:user, session) do
    base = get_in(session.zpw_service_map, ["reaction"]) || []
    service_url = List.first(base) || "https://reaction.chat.zalo.me"
    Url.build_for_session("#{service_url}/api/message/reaction", %{}, session)
  end

  defp build_url(:group, session) do
    base = get_in(session.zpw_service_map, ["reaction"]) || []
    service_url = List.first(base) || "https://reaction.chat.zalo.me"
    Url.build_for_session("#{service_url}/api/group/reaction", %{}, session)
  end

  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> String.to_integer(val)
    end
  end

  defp transform_response({:ok, %{"msgIds" => msg_ids}}) when is_binary(msg_ids) do
    case Jason.decode(msg_ids) do
      {:ok, ids} -> {:ok, %{msg_ids: ids}}
      {:error, _} -> {:ok, %{msg_ids: []}}
    end
  end

  defp transform_response({:ok, %{"msgIds" => msg_ids}}) when is_list(msg_ids) do
    {:ok, %{msg_ids: msg_ids}}
  end

  defp transform_response({:ok, data}), do: {:ok, data}
  defp transform_response(error), do: error
end
