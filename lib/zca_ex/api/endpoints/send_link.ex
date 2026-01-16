defmodule ZcaEx.Api.Endpoints.SendLink do
  @moduledoc """
  Send URL preview messages.

  ## Example

      SendLink.send(%{link: "https://example.com"}, "user_id", :user, session, creds)
      SendLink.send(%{link: "https://example.com", msg: "Check this out"}, "group_id", :group, session, creds)
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Api.Endpoints.ParseLink
  alias ZcaEx.Error

  @type options :: %{
          required(:link) => String.t(),
          optional(:msg) => String.t(),
          optional(:ttl) => integer()
        }

  @doc "Send a link message to a user or group"
  @spec send(options(), String.t(), :user | :group, Session.t(), Credentials.t()) ::
          {:ok, %{msg_id: String.t()}} | {:error, Error.t()}
  def send(options, thread_id, thread_type, session, credentials) do
    with :ok <- validate_options(options),
         :ok <- validate_thread_id(thread_id),
         {:ok, link_data} <- ParseLink.parse(options.link, session, credentials) do
      url = build_url(session, thread_type)
      params = build_params(options, link_data, thread_id, thread_type, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(credentials.imei, url, body, credentials.user_agent) do
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

  @doc "Build the send link URL"
  @spec build_url(Session.t(), :user | :group) :: String.t()
  def build_url(session, :user) do
    base = get_in(session.zpw_service_map, ["chat", Access.at(0)]) <> "/api/message/link"
    Url.build(base, %{}, nretry: 0, api_type: session.api_type, version: session.api_version)
  end

  def build_url(session, :group) do
    base = get_in(session.zpw_service_map, ["group", Access.at(0)]) <> "/api/group/sendlink"
    Url.build(base, %{}, nretry: 0, api_type: session.api_type, version: session.api_version)
  end

  @doc "Build API params from options and link metadata"
  @spec build_params(options(), map(), String.t(), :user | :group, Credentials.t()) :: map()
  def build_params(options, link_metadata, thread_id, thread_type, credentials) do
    msg = build_message(options)
    is_group = thread_type == :group
    link_data = link_metadata.data

    base_params = %{
      msg: msg,
      href: link_data.href,
      src: link_data.src,
      title: link_data.title,
      desc: link_data.desc,
      thumb: link_data.thumb,
      type: 2,
      media: Jason.encode!(link_data.media),
      ttl: options[:ttl] || 0,
      clientId: System.system_time(:millisecond)
    }

    thread_params =
      if is_group do
        %{grid: thread_id, imei: credentials.imei}
      else
        %{toId: thread_id, mentionInfo: ""}
      end

    Map.merge(base_params, thread_params)
  end

  defp build_message(%{msg: msg, link: link}) when is_binary(msg) and byte_size(msg) > 0 do
    trimmed = String.trim(msg)

    if String.contains?(trimmed, link) do
      trimmed
    else
      trimmed <> " " <> link
    end
  end

  defp build_message(%{link: link}), do: link

  defp validate_options(%{link: link}) when is_binary(link) and byte_size(link) > 0, do: :ok
  defp validate_options(_), do: {:error, %Error{message: "Missing link", code: nil}}

  defp validate_thread_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  defp validate_thread_id(_), do: {:error, %Error{message: "Missing threadId", code: nil}}

  defp extract_msg_id({:ok, %{"msgId" => msg_id}}), do: {:ok, %{msg_id: msg_id}}
  defp extract_msg_id({:ok, data}) when is_map(data), do: {:ok, data}
  defp extract_msg_id({:error, _} = error), do: error
end
