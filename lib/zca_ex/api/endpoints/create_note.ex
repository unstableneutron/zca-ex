defmodule ZcaEx.Api.Endpoints.CreateNote do
  @moduledoc "Create a note (topic) in a group board"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Create a note in a group.

  ## Parameters
    - group_id: Group ID (non-empty string)
    - title: Note title (non-empty string)
    - pin?: Whether to pin the note (default: false)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, note_detail}` on success with params parsed from JSON
    - `{:error, Error.t()}` on failure
  """
  @spec create(String.t(), String.t(), boolean(), Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def create(group_id, title, session, credentials), do: create(group_id, title, false, session, credentials)

  def create(group_id, _title, _pin?, _session, _credentials)
      when not is_binary(group_id) or group_id == "" do
    {:error, Error.new(:api, "group_id must be a non-empty string", code: :invalid_input)}
  end

  def create(_group_id, title, _pin?, _session, _credentials)
      when not is_binary(title) or title == "" do
    {:error, Error.new(:api, "title must be a non-empty string", code: :invalid_input)}
  end

  def create(_group_id, _title, pin?, _session, _credentials) when not is_boolean(pin?) do
    {:error, Error.new(:api, "pin? must be a boolean", code: :invalid_input)}
  end

  def create(group_id, title, pin?, session, credentials) do
    with {:ok, params} <- build_params(group_id, title, pin?, credentials),
         {:ok, encrypted_params} <- encrypt_params(session.secret_key, params) do
      url = build_url(session)
      body = build_form_body(%{params: encrypted_params})

      case AccountClient.post(session.uid, url, body, credentials.user_agent) do
        {:ok, response} ->
          case Response.parse(response, session.secret_key) do
            {:ok, data} -> {:ok, transform_note_detail(data)}
            {:error, _} = error -> error
          end

        {:error, reason} ->
          {:error, Error.new(:network, "Request failed: #{inspect(reason)}", reason: reason)}
      end
    end
  end

  @doc "Build URL for create note endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session) <> "/api/board/topic/createv2"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t(), boolean(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def build_params(group_id, title, pin?, credentials) do
    case Jason.encode(%{title: title}) do
      {:ok, params_json} ->
        {:ok, %{
          grid: group_id,
          type: 0,
          color: -16_777_216,
          emoji: "",
          startTime: -1,
          duration: -1,
          params: params_json,
          repeat: 0,
          src: 1,
          imei: credentials.imei,
          pinAct: if(pin?, do: 1, else: 0)
        }}
      {:error, reason} ->
        {:error, Error.new(:api, "Failed to encode params: #{inspect(reason)}", code: :invalid_input)}
    end
  end

  @doc "Transform note detail by parsing params JSON string"
  @spec transform_note_detail(map()) :: map()
  def transform_note_detail(data) when is_map(data) do
    params = data["params"] || data[:params]

    parsed_params =
      case params do
        str when is_binary(str) ->
          case Jason.decode(str) do
            {:ok, p} -> p
            {:error, _} -> str
          end

        other ->
          other
      end

    Map.put(data, :params, parsed_params)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["group_board"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "group_board service URL not found"
    end
  end
end
