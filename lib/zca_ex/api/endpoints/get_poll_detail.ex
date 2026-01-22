defmodule ZcaEx.Api.Endpoints.GetPollDetail do
  @moduledoc "Get poll detail by poll_id"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Get poll detail by poll_id.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - poll_id: Poll ID (integer)

  ## Returns
    - `{:ok, map()}` with poll detail on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), integer()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(session, credentials, poll_id) do
    with :ok <- validate_poll_id(poll_id) do
      params = build_params(poll_id, credentials.imei)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(session)
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(session.uid, url, body, credentials.user_agent) do
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
  end

  @doc "Validate poll_id"
  @spec validate_poll_id(term()) :: :ok | {:error, Error.t()}
  def validate_poll_id(poll_id) when is_integer(poll_id) and poll_id > 0, do: :ok

  def validate_poll_id(poll_id) when is_integer(poll_id),
    do: {:error, %Error{message: "poll_id must be a positive integer", code: nil}}

  def validate_poll_id(nil), do: {:error, %Error{message: "poll_id is required", code: nil}}

  def validate_poll_id(_),
    do: {:error, %Error{message: "poll_id must be a positive integer", code: nil}}

  @doc "Build URL for get poll detail endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session, :group) <> "/api/poll/detail"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    build_url(session)
  end

  @doc "Build params for encryption"
  @spec build_params(integer(), String.t()) :: map()
  def build_params(poll_id, imei) do
    %{
      poll_id: poll_id,
      imei: imei
    }
  end

  @doc "Transform API response to Elixir-style keys"
  @spec transform_response(map()) :: map()
  def transform_response(data) do
    %{
      poll_id: data["poll_id"] || data[:poll_id],
      creator: data["creator"] || data[:creator],
      question: data["question"] || data[:question],
      options: transform_poll_options(data["options"] || data[:options] || []),
      created_time: data["created_time"] || data[:created_time],
      expired_time: data["expired_time"] || data[:expired_time],
      allow_multi_choices: data["allow_multi_choices"] || data[:allow_multi_choices],
      allow_add_new_option: data["allow_add_new_option"] || data[:allow_add_new_option],
      is_hide_vote_preview: data["is_hide_vote_preview"] || data[:is_hide_vote_preview],
      is_anonymous: data["is_anonymous"] || data[:is_anonymous],
      group_id: data["group_id"] || data[:group_id]
    }
  end

  defp transform_poll_options(options) when is_list(options) do
    Enum.map(options, fn opt ->
      %{
        option_id: opt["option_id"] || opt[:option_id],
        content: opt["content"] || opt[:content],
        vote_count: opt["vote_count"] || opt[:vote_count] || 0,
        voters: opt["voters"] || opt[:voters] || []
      }
    end)
  end

  defp transform_poll_options(_), do: []

  defp get_service_url(session, service) do
    service_key = to_string(service)

    case get_in(session.zpw_service_map, [service_key]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for #{service}"
    end
  end
end
