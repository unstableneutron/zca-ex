defmodule ZcaEx.Api.Endpoints.GetReminderResponses do
  @moduledoc "Get responses (accept/reject members) for a reminder"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @type reminder_responses :: %{
          reject_members: [String.t()],
          accept_members: [String.t()]
        }

  @doc """
  Get responses for a reminder.

  ## Parameters
    - reminder_id: The reminder/event ID
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, reminder_responses()}` with accept/reject member lists on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(String.t(), Session.t(), Credentials.t()) ::
          {:ok, reminder_responses()} | {:error, Error.t()}
  def call(reminder_id, session, credentials) do
    params = build_params(reminder_id)

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
          {:ok, response} ->
            case Response.parse(response, session.secret_key) do
              {:ok, data} -> {:ok, transform_response(data)}
              {:error, _} = error -> error
            end

          {:error, reason} ->
            {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Build URL with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group_board) <> "/api/board/topic/listResponseEvent"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group_board) <> "/api/board/topic/listResponseEvent"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t()) :: map()
  def build_params(reminder_id) do
    %{eventId: reminder_id}
  end

  @doc "Transform response to Elixir-friendly format"
  @spec transform_response(map()) :: reminder_responses()
  def transform_response(data) do
    %{
      reject_members: data["rejectMember"] || data[:rejectMember] || [],
      accept_members: data["acceptMember"] || data[:acceptMember] || []
    }
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
