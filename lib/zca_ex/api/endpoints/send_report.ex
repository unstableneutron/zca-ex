defmodule ZcaEx.Api.Endpoints.SendReport do
  @moduledoc """
  Send a report for a user or group.

  ## Report Reasons
    - `:sensitive` (1) - Sensitive content
    - `:annoy` (2) - Annoying/spam behavior
    - `:fraud` (3) - Fraudulent activity
    - `:other` (0) - Other reason (requires content)
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type thread_type :: :user | :group
  @type reason :: :sensitive | :annoy | :fraud | :other

  @valid_reasons [:sensitive, :annoy, :fraud, :other]

  @doc """
  Send a report for a user or group.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - thread_id: ID of the user or group to report
    - thread_type: `:user` or `:group`
    - reason: Report reason (`:sensitive`, `:annoy`, `:fraud`, or `:other`)
    - content: Required when reason is `:other`, optional otherwise

  ## Returns
    - `{:ok, %{report_id: String.t()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), String.t(), thread_type(), reason(), String.t() | nil) ::
          {:ok, %{report_id: String.t()}} | {:error, Error.t()}
  def call(session, credentials, thread_id, thread_type, reason, content \\ nil) do
    with :ok <- validate_thread_id(thread_id),
         :ok <- validate_thread_type(thread_type),
         :ok <- validate_reason(reason),
         :ok <- validate_content(reason, content),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(thread_id, thread_type, reason, content, credentials.imei)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, thread_type, session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, data} -> transform_response(data)
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

  @doc false
  @spec validate_thread_id(term()) :: :ok | {:error, Error.t()}
  def validate_thread_id(thread_id) when is_binary(thread_id) and byte_size(thread_id) > 0, do: :ok
  def validate_thread_id(nil), do: {:error, Error.new(:api, "thread_id is required", code: :invalid_input)}
  def validate_thread_id(<<>>), do: {:error, Error.new(:api, "thread_id cannot be empty", code: :invalid_input)}
  def validate_thread_id(_), do: {:error, Error.new(:api, "thread_id must be a non-empty string", code: :invalid_input)}

  @doc false
  @spec validate_thread_type(term()) :: :ok | {:error, Error.t()}
  def validate_thread_type(type) when type in [:user, :group], do: :ok
  def validate_thread_type(_), do: {:error, Error.new(:api, "thread_type must be :user or :group", code: :invalid_input)}

  @doc false
  @spec validate_reason(term()) :: :ok | {:error, Error.t()}
  def validate_reason(reason) when reason in @valid_reasons, do: :ok
  def validate_reason(_), do: {:error, Error.new(:api, "reason must be :sensitive, :annoy, :fraud, or :other", code: :invalid_input)}

  @doc false
  @spec validate_content(reason(), term()) :: :ok | {:error, Error.t()}
  def validate_content(:other, nil), do: {:error, Error.new(:api, "content is required when reason is :other", code: :invalid_input)}
  def validate_content(:other, <<>>), do: {:error, Error.new(:api, "content cannot be empty when reason is :other", code: :invalid_input)}
  def validate_content(:other, content) when is_binary(content), do: :ok
  def validate_content(:other, _), do: {:error, Error.new(:api, "content must be a string", code: :invalid_input)}
  def validate_content(_, _), do: :ok

  @doc false
  @spec reason_to_value(reason()) :: integer()
  def reason_to_value(:sensitive), do: 1
  def reason_to_value(:annoy), do: 2
  def reason_to_value(:fraud), do: 3
  def reason_to_value(:other), do: 0

  @doc false
  @spec build_params(String.t(), thread_type(), reason(), String.t() | nil, String.t()) :: map()
  def build_params(thread_id, :user, reason, content, _imei) do
    base = %{
      idTo: thread_id,
      objId: "person.profile",
      reason: Integer.to_string(reason_to_value(reason))
    }

    if reason == :other do
      Map.put(base, :content, content)
    else
      base
    end
  end

  def build_params(thread_id, :group, reason, content, imei) do
    %{
      uidTo: thread_id,
      type: 14,
      reason: reason_to_value(reason),
      content: if(reason == :other, do: content, else: ""),
      imei: imei
    }
  end

  @doc "Build URL for send report endpoint"
  @spec build_url(String.t(), thread_type(), Session.t()) :: String.t()
  def build_url(service_url, :user, session) do
    Url.build_for_session("#{service_url}/api/report/abuse-v2", %{}, session)
  end

  def build_url(service_url, :group, session) do
    Url.build_for_session("#{service_url}/api/social/profile/reportabuse", %{}, session)
  end

  @doc "Build base URL (for testing)"
  @spec build_base_url(Session.t(), thread_type()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session, thread_type) do
    case get_service_url(session) do
      {:ok, service_url} ->
        {:ok, build_url(service_url, thread_type, session)}

      {:error, _} = error ->
        error
    end
  end

  @spec get_service_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["profile"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "profile service URL not found", code: :service_not_found)}
    end
  end

  defp transform_response(data) when is_map(data) do
    case data["reportId"] || data[:reportId] do
      nil -> {:error, Error.new(:api, "Invalid response: missing reportId", code: :invalid_response)}
      report_id -> {:ok, %{report_id: to_string(report_id)}}
    end
  end

  defp transform_response(_), do: {:error, Error.new(:api, "Invalid response format", code: :invalid_response)}
end
