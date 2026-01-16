defmodule ZcaEx.Api.Endpoints.SendMessage do
  @moduledoc """
  Send text messages to users or groups.

  ## Example

      # Simple text
      SendMessage.send("Hello!", "user_id", :user, session, creds)

      # With mentions (group only)
      SendMessage.send(%{msg: "Hi @user", mentions: [%{uid: "123", pos: 3, len: 5}]}, "group_id", :group, session, creds)

      # With quote
      SendMessage.send(%{msg: "Reply", quote: quote_data}, "user_id", :user, session, creds)
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Model.{Mention, TextStyle, Urgency}
  alias ZcaEx.Account.Session
  alias ZcaEx.Error

  @type quote_data :: %{
          content: String.t() | map(),
          msg_type: String.t(),
          property_ext: map() | nil,
          uid_from: String.t(),
          msg_id: integer(),
          cli_msg_id: integer(),
          ts: integer(),
          ttl: integer()
        }

  @type message_content ::
          String.t()
          | %{
              required(:msg) => String.t(),
              optional(:styles) => [TextStyle.t()],
              optional(:urgency) => Urgency.t(),
              optional(:quote) => quote_data(),
              optional(:mentions) => [Mention.t() | map()],
              optional(:ttl) => non_neg_integer()
            }

  @type send_result :: {:ok, %{msg_id: integer()}} | {:error, Error.t()}

  @doc "Send a message to a user or group"
  @spec send(message_content(), String.t(), :user | :group, Session.t(), Credentials.t()) ::
          send_result()
  def send(message, thread_id, thread_type, session, credentials)

  def send(msg, thread_id, thread_type, session, creds) when is_binary(msg) do
    send(%{msg: msg}, thread_id, thread_type, session, creds)
  end

  def send(%{msg: msg} = content, thread_id, thread_type, session, creds) do
    with :ok <- validate_message(msg),
         :ok <- validate_thread_id(thread_id),
         {:ok, mentions} <- handle_mentions(content[:mentions], msg, thread_type),
         :ok <- validate_quote(content[:quote]) do
      has_quote = not is_nil(content[:quote])
      has_mentions = mentions != []

      url = build_message_url(session, thread_type, has_quote, has_mentions)
      params = build_params(content, thread_id, thread_type, mentions, creds)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(creds.imei, url, body, creds.user_agent) do
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
  end

  @doc "Build the message URL based on thread type and message content"
  @spec build_message_url(Session.t(), :user | :group, boolean(), boolean()) :: String.t()
  def build_message_url(session, thread_type, has_quote, has_mentions) do
    base = get_base_url(session, thread_type)
    path = get_path(thread_type, has_quote, has_mentions)

    url = base <> path

    Url.build(url, %{}, nretry: 0, api_type: session.api_type, version: session.api_version)
  end

  @doc false
  def get_base_url(session, :user) do
    get_in(session.zpw_service_map, ["chat", Access.at(0)]) <> "/api/message"
  end

  def get_base_url(session, :group) do
    get_in(session.zpw_service_map, ["group", Access.at(0)]) <> "/api/group"
  end

  @doc false
  def get_path(_thread_type, true, _has_mentions), do: "/quote"
  def get_path(:group, false, true), do: "/mention"
  def get_path(:group, false, false), do: "/sendmsg"
  def get_path(:user, false, _has_mentions), do: "/sms"

  @doc "Build API params from message content"
  @spec build_params(map(), String.t(), :user | :group, [map()], Credentials.t()) :: map()
  def build_params(content, thread_id, thread_type, mentions, creds) do
    base_params =
      if content[:quote] do
        build_quote_params(content, thread_id, thread_type, mentions, creds)
      else
        build_text_params(content, thread_id, thread_type, mentions, creds)
      end

    base_params
    |> add_styles(content[:styles])
    |> add_urgency(content[:urgency])
    |> remove_nil_values()
  end

  defp build_text_params(content, thread_id, thread_type, mentions, creds) do
    is_group = thread_type == :group

    %{
      message: content.msg,
      clientId: System.system_time(:millisecond),
      mentionInfo: if(mentions != [], do: Jason.encode!(mentions)),
      imei: if(!is_group, do: creds.imei),
      ttl: content[:ttl] || 0,
      visibility: if(is_group, do: 0),
      toid: if(!is_group, do: thread_id),
      grid: if(is_group, do: thread_id)
    }
  end

  defp build_quote_params(content, thread_id, thread_type, mentions, creds) do
    is_group = thread_type == :group
    quote = content[:quote]

    %{
      toid: if(!is_group, do: thread_id),
      grid: if(is_group, do: thread_id),
      message: content.msg,
      clientId: System.system_time(:millisecond),
      mentionInfo: if(mentions != [], do: Jason.encode!(mentions)),
      qmsgOwner: quote[:uid_from],
      qmsgId: quote[:msg_id],
      qmsgCliId: quote[:cli_msg_id],
      qmsgType: get_client_message_type(quote[:msg_type]),
      qmsgTs: quote[:ts],
      qmsg: prepare_qmsg(quote),
      imei: if(!is_group, do: creds.imei),
      visibility: if(is_group, do: 0),
      qmsgAttach: if(is_group, do: Jason.encode!(prepare_qmsg_attach(quote))),
      qmsgTTL: quote[:ttl],
      ttl: content[:ttl] || 0
    }
  end

  defp add_styles(params, nil), do: params

  defp add_styles(params, styles) when is_list(styles) do
    text_properties = %{
      "styles" =>
        Enum.map(styles, fn style ->
          TextStyle.to_api_format(style)
        end),
      "ver" => 0
    }

    Map.put(params, :textProperties, Jason.encode!(text_properties))
  end

  defp add_urgency(params, nil), do: params
  defp add_urgency(params, :default), do: params

  defp add_urgency(params, urgency) when urgency in [:important, :urgent] do
    Map.put(params, :metaData, %{urgency: Urgency.to_api_value(urgency)})
  end

  @doc "Handle and validate mentions"
  @spec handle_mentions([map()] | nil, String.t(), :user | :group) ::
          {:ok, [map()]} | {:error, Error.t()}
  def handle_mentions(nil, _msg, _thread_type), do: {:ok, []}
  def handle_mentions([], _msg, _thread_type), do: {:ok, []}

  def handle_mentions(_mentions, _msg, :user) do
    {:ok, []}
  end

  def handle_mentions(mentions, msg, :group) when is_list(mentions) do
    filtered =
      mentions
      |> Enum.filter(fn m ->
        pos = get_mention_field(m, :pos)
        uid = get_mention_field(m, :uid)
        len = get_mention_field(m, :len)

        pos >= 0 && uid && len > 0
      end)
      |> Enum.map(fn m ->
        uid = get_mention_field(m, :uid)

        %{
          pos: get_mention_field(m, :pos),
          uid: to_string(uid),
          len: get_mention_field(m, :len),
          type: if(to_string(uid) == "-1", do: 1, else: 0)
        }
      end)

    total_len = Enum.reduce(filtered, 0, fn m, acc -> acc + m.len end)

    if total_len > String.length(msg) do
      {:error, %Error{message: "Invalid mentions: total mention len exceeds message length", code: nil}}
    else
      {:ok, filtered}
    end
  end

  defp get_mention_field(%Mention{} = m, :pos), do: m.pos
  defp get_mention_field(%Mention{} = m, :uid), do: m.uid
  defp get_mention_field(%Mention{} = m, :len), do: m.len
  defp get_mention_field(m, field) when is_map(m), do: Map.get(m, field) || Map.get(m, to_string(field))

  defp validate_message(msg) when is_binary(msg) and byte_size(msg) > 0, do: :ok
  defp validate_message(_), do: {:error, %Error{message: "Missing message content", code: nil}}

  defp validate_thread_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  defp validate_thread_id(_), do: {:error, %Error{message: "Missing threadId", code: nil}}

  defp validate_quote(nil), do: :ok

  defp validate_quote(%{msg_type: "webchat", content: content}) when is_map(content) do
    {:error, %Error{message: "This kind of `webchat` quote type is not available", code: nil}}
  end

  defp validate_quote(%{msg_type: "group.poll"}) do
    {:error, %Error{message: "The `group.poll` quote type is not available", code: nil}}
  end

  defp validate_quote(_), do: :ok

  defp get_client_message_type(nil), do: nil
  defp get_client_message_type("chat.photo"), do: 1
  defp get_client_message_type("chat.video"), do: 2
  defp get_client_message_type("chat.sticker"), do: 3
  defp get_client_message_type("chat.gif"), do: 4
  defp get_client_message_type("chat.link"), do: 5
  defp get_client_message_type("chat.file"), do: 6
  defp get_client_message_type("chat.voice"), do: 7
  defp get_client_message_type("chat.location"), do: 8
  defp get_client_message_type("chat.businessCard"), do: 9
  defp get_client_message_type("chat.todo"), do: 10
  defp get_client_message_type(_), do: 0

  defp prepare_qmsg(%{msg_type: "chat.todo", content: %{"params" => params}}) when is_binary(params) do
    case Jason.decode(params) do
      {:ok, %{"item" => %{"content" => content}}} -> content
      _ -> ""
    end
  end

  defp prepare_qmsg(%{content: content}) when is_binary(content), do: content
  defp prepare_qmsg(_), do: ""

  defp prepare_qmsg_attach(%{content: content}) when is_binary(content), do: %{}

  defp prepare_qmsg_attach(%{msg_type: "chat.todo"}) do
    %{
      "properties" => %{
        "color" => 0,
        "size" => 0,
        "type" => 0,
        "subType" => 0,
        "ext" => "{\"shouldParseLinkOrContact\":0}"
      }
    }
  end

  defp prepare_qmsg_attach(%{content: content}) when is_map(content) do
    %{
      "thumbUrl" => content["thumb"],
      "oriUrl" => content["href"],
      "normalUrl" => content["href"]
    }
    |> Map.merge(content)
  end

  defp prepare_qmsg_attach(%{property_ext: ext}) when not is_nil(ext), do: ext
  defp prepare_qmsg_attach(_), do: %{}

  defp remove_nil_values(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp extract_msg_id({:ok, %{"msgId" => msg_id}}), do: {:ok, %{msg_id: msg_id}}
  defp extract_msg_id({:ok, data}) when is_map(data), do: {:ok, data}
  defp extract_msg_id({:error, _} = error), do: error
end
