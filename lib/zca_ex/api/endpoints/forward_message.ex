defmodule ZcaEx.Api.Endpoints.ForwardMessage do
  @moduledoc """
  Forward messages to multiple users or groups.

  ## Example

      # Forward simple message
      ForwardMessage.call(%{message: "Hello"}, ["user1", "user2"], :user, session, creds)

      # Forward with reference (original message metadata)
      ForwardMessage.call(
        %{message: "Check this out", reference: %{id: "msg123", ts: 1700000000, log_src_type: 1, fw_lvl: 1}},
        ["group1"],
        :group,
        session,
        creds
      )
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type reference_data :: %{
          required(:id) => String.t(),
          required(:ts) => integer(),
          required(:log_src_type) => integer(),
          required(:fw_lvl) => integer()
        }

  @type payload :: %{
          required(:message) => String.t(),
          optional(:ttl) => non_neg_integer(),
          optional(:reference) => reference_data()
        }

  @type forward_success :: %{client_id: String.t(), msg_id: String.t()}
  @type forward_fail :: %{client_id: String.t(), error_code: String.t()}

  @type forward_result ::
          {:ok, %{success: [forward_success()], fail: [forward_fail()]}} | {:error, Error.t()}

  @doc "Forward a message to multiple users or groups"
  @spec call(payload(), [String.t()], :user | :group, Session.t(), Credentials.t()) ::
          forward_result()
  def call(payload, thread_ids, thread_type, session, credentials) do
    with :ok <- validate_message(payload[:message]),
         :ok <- validate_thread_ids(thread_ids) do
      url = build_url(session, thread_type)
      params = build_params(payload, thread_ids, thread_type, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
            {:ok, response} ->
              Response.parse(response, session.secret_key)
              |> extract_result()

            {:error, reason} ->
              {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "Build the forward URL based on thread type"
  @spec build_url(Session.t(), :user | :group) :: String.t()
  def build_url(session, thread_type) do
    base = get_base_url(session)
    path = get_path(thread_type)

    url = base <> path

    Url.build(url, %{}, nretry: 0, api_type: session.api_type, version: session.api_version)
  end

  @doc false
  def get_base_url(session) do
    get_in(session.zpw_service_map, ["file", Access.at(0)])
  end

  @doc false
  def get_path(:user), do: "/api/message/mforward"
  def get_path(:group), do: "/api/group/mforward"

  @doc "Build API params from payload and thread IDs"
  @spec build_params(payload(), [String.t()], :user | :group, Credentials.t()) :: map()
  def build_params(payload, thread_ids, thread_type, credentials) do
    timestamp = System.system_time(:millisecond)
    client_id = to_string(timestamp)
    ttl = payload[:ttl] || 0

    msg_info = build_msg_info(payload)
    decor_log = build_decor_log(payload[:reference])

    base_params = %{
      ttl: ttl,
      msgType: "1",
      totalIds: length(thread_ids),
      msgInfo: Jason.encode!(msg_info),
      decorLog: Jason.encode!(decor_log)
    }

    case thread_type do
      :user ->
        to_ids =
          Enum.map(thread_ids, fn thread_id ->
            %{clientId: client_id, toUid: thread_id, ttl: ttl}
          end)

        Map.merge(base_params, %{toIds: to_ids, imei: credentials.imei})

      :group ->
        grids =
          Enum.map(thread_ids, fn thread_id ->
            %{clientId: client_id, grid: thread_id, ttl: ttl}
          end)

        Map.put(base_params, :grids, grids)
    end
  end

  @doc false
  def build_msg_info(payload) do
    msg_info = %{message: payload[:message]}

    case payload[:reference] do
      nil ->
        msg_info

      ref ->
        reference_data = %{
          id: ref[:id],
          ts: ref[:ts],
          logSrcType: ref[:log_src_type],
          fwLvl: ref[:fw_lvl]
        }

        Map.put(msg_info, :reference, Jason.encode!(%{type: 3, data: Jason.encode!(reference_data)}))
    end
  end

  @doc false
  def build_decor_log(nil), do: nil

  def build_decor_log(reference) do
    %{
      fw: %{
        pmsg: %{st: 1, ts: reference[:ts], id: reference[:id]},
        rmsg: %{st: 1, ts: reference[:ts], id: reference[:id]},
        fwLvl: reference[:fw_lvl]
      }
    }
  end

  defp validate_message(msg) when is_binary(msg) and byte_size(msg) > 0, do: :ok
  defp validate_message(_), do: {:error, %Error{message: "Missing message content", code: nil}}

  defp validate_thread_ids(ids) when is_list(ids) and length(ids) > 0, do: :ok
  defp validate_thread_ids(_), do: {:error, %Error{message: "Missing thread IDs", code: nil}}

  defp extract_result({:ok, %{"success" => success, "fail" => fail}}) do
    success_items =
      Enum.map(success || [], fn item ->
        %{client_id: item["clientId"], msg_id: item["msgId"]}
      end)

    fail_items =
      Enum.map(fail || [], fn item ->
        %{client_id: item["clientId"], error_code: item["error_code"]}
      end)

    {:ok, %{success: success_items, fail: fail_items}}
  end

  defp extract_result({:ok, data}) when is_map(data) do
    {:ok, %{success: [], fail: [], raw: data}}
  end

  defp extract_result({:error, _} = error), do: error
end
