defmodule ZcaEx.Api.Endpoints.CreateAutoReply do
  @moduledoc """
  Create an auto-reply rule.

  ## Scopes
    - 0: All messages
    - 1: Contacts only
    - 2: Specific users (include)
    - 3: Specific users (exclude)

  Note: This API is used for zBusiness accounts.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @valid_scopes [0, 1, 2, 3]

  @doc """
  Create an auto-reply rule.

  ## Parameters
    - content: Reply message content (non-empty string)
    - enabled?: Whether the rule is enabled
    - start_time: Start Unix timestamp in milliseconds (non-negative integer)
    - end_time: End Unix timestamp in milliseconds (positive integer, > start_time)
    - scope: Target scope (0-3)
    - uids: User IDs for scope 2 or 3 (optional, list of strings)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{item: map(), version: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec create(String.t(), boolean(), integer(), integer(), integer(), String.t() | [String.t()] | nil, Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def create(content, enabled?, start_time, end_time, scope, uids, session, credentials) do
    with :ok <- validate_content(content),
         :ok <- validate_enabled(enabled?),
         :ok <- validate_times(start_time, end_time),
         :ok <- validate_scope(scope),
         :ok <- validate_uids(scope, uids),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(content, enabled?, start_time, end_time, scope, uids, credentials)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, data} -> {:ok, transform_response(data)}
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

  defp validate_content(content) when is_binary(content) and byte_size(content) > 0, do: :ok
  defp validate_content(_), do: {:error, Error.new(:api, "content must be a non-empty string", code: :invalid_input)}

  defp validate_enabled(enabled?) when is_boolean(enabled?), do: :ok
  defp validate_enabled(_), do: {:error, Error.new(:api, "enabled? must be a boolean", code: :invalid_input)}

  defp validate_times(start_time, end_time)
       when is_integer(start_time) and is_integer(end_time) and start_time >= 0 and end_time > start_time do
    :ok
  end
  defp validate_times(start_time, _) when not is_integer(start_time) or start_time < 0 do
    {:error, Error.new(:api, "start_time must be a non-negative integer", code: :invalid_input)}
  end
  defp validate_times(_, end_time) when not is_integer(end_time) do
    {:error, Error.new(:api, "end_time must be an integer", code: :invalid_input)}
  end
  defp validate_times(_, _) do
    {:error, Error.new(:api, "end_time must be greater than start_time", code: :invalid_input)}
  end

  defp validate_scope(scope) when scope in @valid_scopes, do: :ok
  defp validate_scope(_), do: {:error, Error.new(:api, "scope must be 0, 1, 2, or 3", code: :invalid_input)}

  defp validate_uids(scope, uids) when scope in [2, 3] do
    case normalize_uids(uids) do
      [] -> {:error, Error.new(:api, "uids required for scope 2 or 3", code: :invalid_input)}
      _ -> :ok
    end
  end
  defp validate_uids(_scope, _uids), do: :ok

  defp normalize_uids(nil), do: []
  defp normalize_uids(uid) when is_binary(uid), do: [uid]
  defp normalize_uids(uids) when is_list(uids), do: uids
  defp normalize_uids(_), do: []

  @doc false
  def build_params(content, enabled?, start_time, end_time, scope, uids, credentials) do
    result_uids = if scope in [2, 3], do: normalize_uids(uids), else: []

    %{
      cliLang: credentials.language,
      enable: enabled?,
      content: content,
      startTime: start_time,
      endTime: end_time,
      recurrence: ["RRULE:FREQ=DAILY;"],
      scope: scope,
      uids: result_uids
    }
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/autoreply/create"
    Url.build_for_session(base_url, %{}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["auto_reply"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "auto_reply service URL not found", code: :service_not_found)}
    end
  end

  defp transform_response(data) when is_map(data) do
    %{
      item: data["item"] || data[:item],
      version: data["version"] || data[:version]
    }
  end
end
