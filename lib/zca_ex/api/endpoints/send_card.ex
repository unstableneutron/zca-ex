defmodule ZcaEx.Api.Endpoints.SendCard do
  @moduledoc """
  Send contact card messages.

  ## Example

      # Automatically fetches QR code URL
      SendCard.call(%{user_id: "contact_id"}, "recipient_id", :user, session, creds)
      SendCard.call(%{user_id: "contact_id", phone_number: "+1234567890"}, "group_id", :group, session, creds)
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Api.Endpoints.GetQR
  alias ZcaEx.Error

  @type card_options :: %{
          required(:user_id) => String.t(),
          optional(:phone_number) => String.t(),
          optional(:ttl) => integer()
        }

  @doc "Send a contact card to a user or group"
  @spec call(card_options(), String.t(), :user | :group, Session.t(), Credentials.t()) ::
          {:ok, %{msg_id: integer()}} | {:error, Error.t()}
  def call(options, thread_id, thread_type, session, credentials) do
    with :ok <- validate_user_id(options[:user_id]),
         :ok <- validate_thread_id(thread_id),
         {:ok, qr_data} <- GetQR.get(options.user_id, session, credentials),
         {:ok, qr_url} <- extract_qr_url(qr_data, options.user_id) do
      options_with_qr = Map.put(options, :qr_code_url, qr_url)
      url = build_url(session, thread_type)
      params = build_params(options_with_qr, thread_id, thread_type, credentials)

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

  @doc "Build the send card URL"
  @spec build_url(Session.t(), :user | :group) :: String.t()
  def build_url(session, :user) do
    base = get_in(session.zpw_service_map, ["file", Access.at(0)]) <> "/api/message/forward"
    Url.build(base, %{}, nretry: 0, api_type: session.api_type, version: session.api_version)
  end

  def build_url(session, :group) do
    base = get_in(session.zpw_service_map, ["file", Access.at(0)]) <> "/api/group/forward"
    Url.build(base, %{}, nretry: 0, api_type: session.api_type, version: session.api_version)
  end

  @doc "Build API params from options"
  @spec build_params(map(), String.t(), :user | :group, Credentials.t()) :: map()
  def build_params(options, thread_id, thread_type, credentials) do
    is_group = thread_type == :group

    msg_info = build_msg_info(options)

    base_params = %{
      ttl: options[:ttl] || 0,
      msgType: 6,
      clientId: to_string(System.system_time(:millisecond)),
      msgInfo: Jason.encode!(msg_info)
    }

    thread_params =
      if is_group do
        %{visibility: 0, grid: thread_id}
      else
        %{toId: thread_id, imei: credentials.imei}
      end

    Map.merge(base_params, thread_params)
  end

  @doc "Build msgInfo object"
  @spec build_msg_info(map()) :: map()
  def build_msg_info(options) do
    base = %{
      contactUid: options.user_id,
      qrCodeUrl: options.qr_code_url
    }

    if options[:phone_number] do
      Map.put(base, :phone, options.phone_number)
    else
      base
    end
  end

  defp validate_user_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  defp validate_user_id(_), do: {:error, %Error{message: "Missing user_id", code: nil}}

  defp validate_thread_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  defp validate_thread_id(_), do: {:error, %Error{message: "Missing threadId", code: nil}}

  defp extract_qr_url(qr_data, user_id) when is_map(qr_data) do
    case Map.get(qr_data, user_id) do
      nil -> {:error, %Error{message: "QR code not found for user", code: nil}}
      url -> {:ok, url}
    end
  end

  defp extract_msg_id({:ok, %{"msgId" => msg_id}}), do: {:ok, %{msg_id: msg_id}}
  defp extract_msg_id({:ok, data}) when is_map(data), do: {:ok, data}
  defp extract_msg_id({:error, _} = error), do: error
end
