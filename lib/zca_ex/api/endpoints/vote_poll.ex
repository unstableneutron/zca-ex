defmodule ZcaEx.Api.Endpoints.VotePoll do
  @moduledoc "Vote on a poll (or unvote by passing empty option_ids)"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Vote on a poll or unvote.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - poll_id: Poll ID (integer)
    - option_ids: List of option IDs to vote for (empty list = unvote)

  ## Returns
    - `{:ok, map()}` with updated options list on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), integer(), [integer()]) ::
          {:ok, map()} | {:error, Error.t()}
  def call(session, credentials, poll_id, option_ids \\ []) do
    with :ok <- validate_poll_id(poll_id),
         :ok <- validate_option_ids(option_ids) do
      params = build_params(poll_id, option_ids, credentials.imei)

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

  @doc "Validate poll_id"
  @spec validate_poll_id(term()) :: :ok | {:error, Error.t()}
  def validate_poll_id(poll_id) when is_integer(poll_id) and poll_id > 0, do: :ok

  def validate_poll_id(poll_id) when is_integer(poll_id),
    do: {:error, %Error{message: "poll_id must be a positive integer", code: nil}}

  def validate_poll_id(nil), do: {:error, %Error{message: "poll_id is required", code: nil}}

  def validate_poll_id(_),
    do: {:error, %Error{message: "poll_id must be a positive integer", code: nil}}

  @doc "Validate option_ids"
  @spec validate_option_ids(term()) :: :ok | {:error, Error.t()}
  def validate_option_ids(option_ids) when is_list(option_ids) do
    if Enum.all?(option_ids, &is_integer/1) do
      :ok
    else
      {:error, %Error{message: "option_ids must be a list of integers", code: nil}}
    end
  end

  def validate_option_ids(_),
    do: {:error, %Error{message: "option_ids must be a list", code: nil}}

  @doc "Build URL for vote poll endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session, :group) <> "/api/poll/vote"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session, :group) <> "/api/poll/vote"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(integer(), [integer()], String.t()) :: map()
  def build_params(poll_id, option_ids, imei) do
    %{
      poll_id: poll_id,
      option_ids: option_ids,
      imei: imei
    }
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
