defmodule ZcaEx.Api.Endpoints.LockPoll do
  @moduledoc "Lock/end a poll"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Lock/end a poll.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - poll_id: Poll ID to lock (required, positive integer)

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), integer()) :: {:ok, :success} | {:error, Error.t()}
  def call(session, credentials, poll_id) do
    case validate_poll_id(poll_id) do
      :ok ->
        params = build_params(poll_id, credentials.imei)

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

      {:error, _} = error ->
        error
    end
  end

  @doc "Validate poll_id"
  @spec validate_poll_id(term()) :: :ok | {:error, Error.t()}
  def validate_poll_id(poll_id) when is_integer(poll_id) and poll_id > 0, do: :ok
  def validate_poll_id(poll_id) when is_integer(poll_id), do: {:error, %Error{message: "poll_id must be a positive integer", code: nil}}
  def validate_poll_id(nil), do: {:error, %Error{message: "poll_id is required", code: nil}}
  def validate_poll_id(_), do: {:error, %Error{message: "poll_id must be a positive integer", code: nil}}

  @doc "Build URL for lock poll endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session) <> "/api/poll/end"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(integer(), String.t()) :: map()
  def build_params(poll_id, imei) do
    %{
      poll_id: poll_id,
      imei: imei
    }
  end

  defp get_service_url(session) do
    service_key = "group"

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service_key}"
    end
  end
end
