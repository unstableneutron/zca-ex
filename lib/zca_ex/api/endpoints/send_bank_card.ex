defmodule ZcaEx.Api.Endpoints.SendBankCard do
  @moduledoc """
  Send a bank card to a thread.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type thread_type :: :user | :group

  @type bin_bank :: %{
          optional(:bin) => String.t(),
          optional(:bankName) => String.t(),
          optional(atom() | String.t()) => term()
        }

  @doc """
  Send a bank card to a thread.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - thread_id: ID of the thread to send to
    - thread_type: :user or :group
    - bin_bank: Bank information map
    - num_acc_bank: Bank account number
    - opts: Options
      - `:name_acc_bank` - Account holder name (default: "---")

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec send(
          Session.t(),
          Credentials.t(),
          String.t(),
          thread_type(),
          bin_bank(),
          String.t(),
          keyword()
        ) ::
          {:ok, :success} | {:error, Error.t()}
  def send(session, credentials, thread_id, thread_type, bin_bank, num_acc_bank, opts \\ []) do
    name_acc_bank = Keyword.get(opts, :name_acc_bank, "---")

    with :ok <- validate_thread_id(thread_id),
         :ok <- validate_thread_type(thread_type),
         :ok <- validate_bin_bank(bin_bank),
         :ok <- validate_num_acc_bank(num_acc_bank),
         :ok <- validate_name_acc_bank(name_acc_bank),
         {:ok, service_url} <- get_service_url(session) do
      now = System.system_time(:millisecond)

      params = build_params(bin_bank, num_acc_bank, name_acc_bank, thread_id, thread_type, now)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, _data} -> {:ok, :success}
                {:error, _} = error -> error
              end

            {:error, reason} ->
              {:error, Error.new(:network, "Request failed: #{inspect(reason)}", reason: reason)}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  defp validate_thread_id(thread_id) when is_binary(thread_id) and byte_size(thread_id) > 0,
    do: :ok

  defp validate_thread_id(nil),
    do: {:error, Error.new(:api, "thread_id is required", code: :invalid_input)}

  defp validate_thread_id(<<>>),
    do: {:error, Error.new(:api, "thread_id cannot be empty", code: :invalid_input)}

  defp validate_thread_id(_),
    do: {:error, Error.new(:api, "thread_id must be a string", code: :invalid_input)}

  defp validate_thread_type(type) when type in [:user, :group], do: :ok

  defp validate_thread_type(_),
    do: {:error, Error.new(:api, "thread_type must be :user or :group", code: :invalid_input)}

  defp validate_bin_bank(bin_bank) when is_map(bin_bank) and map_size(bin_bank) > 0, do: :ok

  defp validate_bin_bank(nil),
    do: {:error, Error.new(:api, "bin_bank is required", code: :invalid_input)}

  defp validate_bin_bank(bin_bank) when is_map(bin_bank),
    do: {:error, Error.new(:api, "bin_bank cannot be empty", code: :invalid_input)}

  defp validate_bin_bank(_),
    do: {:error, Error.new(:api, "bin_bank must be a map", code: :invalid_input)}

  defp validate_num_acc_bank(num) when is_binary(num) and byte_size(num) > 0, do: :ok

  defp validate_num_acc_bank(nil),
    do: {:error, Error.new(:api, "num_acc_bank is required", code: :invalid_input)}

  defp validate_num_acc_bank(<<>>),
    do: {:error, Error.new(:api, "num_acc_bank cannot be empty", code: :invalid_input)}

  defp validate_num_acc_bank(_),
    do: {:error, Error.new(:api, "num_acc_bank must be a string", code: :invalid_input)}

  defp validate_name_acc_bank(nil), do: :ok
  defp validate_name_acc_bank(name) when is_binary(name), do: :ok

  defp validate_name_acc_bank(_),
    do: {:error, Error.new(:api, "name_acc_bank must be nil or a string", code: :invalid_input)}

  @doc false
  def build_params(bin_bank, num_acc_bank, name_acc_bank, thread_id, thread_type, now) do
    dest_type = if thread_type == :group, do: 1, else: 0

    formatted_name =
      if name_acc_bank && name_acc_bank != "", do: String.upcase(name_acc_bank), else: "---"

    %{
      binBank: bin_bank,
      numAccBank: num_acc_bank,
      nameAccBank: formatted_name,
      cliMsgId: Integer.to_string(now),
      tsMsg: now,
      destUid: thread_id,
      destType: dest_type
    }
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/transfer/card"
    Url.build_for_session(base_url, %{}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["zimsg"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "zimsg service URL not found", code: :service_not_found)}
    end
  end
end
