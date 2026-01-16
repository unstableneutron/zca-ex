defmodule ZcaEx.Api.Endpoints.AddPollOptions do
  @moduledoc "Add options to a poll"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Add new options to a poll.

  ## Parameters
    - poll_id: Poll ID (positive integer)
    - session: Authenticated session
    - credentials: Account credentials
    - opts: Options
      - `:options` - List of new options (required), each as `%{voted: bool, content: string}`
      - `:voted_option_ids` - List of already voted option IDs (optional, defaults to [])

  ## Returns
    - `{:ok, %{options: [...]}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(integer(), Session.t(), Credentials.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(poll_id, session, credentials, opts \\ []) do
    new_options = Keyword.get(opts, :options, [])

    with :ok <- validate_poll_id(poll_id),
         :ok <- validate_new_options(new_options),
         {:ok, params} <- build_params(poll_id, opts) do
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
  end

  @doc "Transform API response to Elixir-style keys"
  @spec transform_response(map()) :: map()
  def transform_response(data) do
    %{
      options: transform_poll_options(data["options"] || data[:options] || [])
    }
  end

  defp transform_poll_options(options) when is_list(options) do
    Enum.map(options, fn opt ->
      %{
        option_id: opt["option_id"] || opt[:option_id],
        content: opt["content"] || opt[:content],
        vote_count: opt["votes"] || opt[:votes] || opt["vote_count"] || opt[:vote_count] || 0,
        voted: opt["voted"] || opt[:voted] || false,
        voters: opt["voters"] || opt[:voters] || []
      }
    end)
  end

  defp transform_poll_options(_), do: []

  @doc "Validate poll_id is a positive integer"
  @spec validate_poll_id(any()) :: :ok | {:error, Error.t()}
  def validate_poll_id(poll_id) when is_integer(poll_id) and poll_id > 0, do: :ok
  def validate_poll_id(poll_id) when is_integer(poll_id), do: {:error, %Error{message: "poll_id must be a positive integer", code: nil}}
  def validate_poll_id(nil), do: {:error, %Error{message: "poll_id is required", code: nil}}
  def validate_poll_id(_), do: {:error, %Error{message: "poll_id must be a positive integer", code: nil}}

  @doc "Validate new_options is a non-empty list"
  @spec validate_new_options(any()) :: :ok | {:error, Error.t()}
  def validate_new_options([]), do: {:error, %Error{message: "options cannot be empty", code: nil}}
  def validate_new_options(opts) when is_list(opts), do: :ok
  def validate_new_options(_), do: {:error, %Error{message: "options must be a list", code: nil}}

  @doc "Build URL for add poll options endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group) <> "/api/poll/option/add"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group) <> "/api/poll/option/add"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(integer(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def build_params(poll_id, opts) do
    new_options = Keyword.get(opts, :options, [])
    voted_option_ids = Keyword.get(opts, :voted_option_ids, [])

    case Jason.encode(new_options) do
      {:ok, new_options_json} ->
        {:ok, %{
          poll_id: poll_id,
          new_options: new_options_json,
          voted_option_ids: voted_option_ids
        }}

      {:error, reason} ->
        {:error, %Error{message: "Failed to encode options: #{inspect(reason)}", code: nil}}
    end
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
