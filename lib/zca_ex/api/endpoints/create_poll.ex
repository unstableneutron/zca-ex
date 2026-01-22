defmodule ZcaEx.Api.Endpoints.CreatePoll do
  @moduledoc "Create a new poll in a group"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Create a new poll in a group.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - group_id: Group ID where poll will be created
    - opts: Options
      - `:question` - Poll question (required, non-empty string)
      - `:options` - List of poll options (required, at least 2)
      - `:expired_time` - Expiration time in milliseconds (optional, default 0 = never)
      - `:allow_multi_choices` - Allow multiple choices (optional, default false)
      - `:allow_add_new_option` - Allow adding new options (optional, default false)
      - `:hide_vote_preview` - Hide vote preview (optional, default false)
      - `:is_anonymous` - Anonymous voting (optional, default false)

  ## Returns
    - `{:ok, map()}` with poll detail on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(session, credentials, group_id, opts \\ []) do
    question = Keyword.get(opts, :question)
    options = Keyword.get(opts, :options, [])

    with :ok <- validate_group_id(group_id),
         :ok <- validate_question(question),
         :ok <- validate_options(options) do
      params = build_params(group_id, question, options, credentials.imei, opts)

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

  @doc "Validate group_id"
  @spec validate_group_id(term()) :: :ok | {:error, Error.t()}
  def validate_group_id(group_id) when is_binary(group_id) and byte_size(group_id) > 0, do: :ok
  def validate_group_id(""), do: {:error, %Error{message: "group_id is required", code: nil}}
  def validate_group_id(nil), do: {:error, %Error{message: "group_id is required", code: nil}}

  def validate_group_id(_),
    do: {:error, %Error{message: "group_id must be a non-empty string", code: nil}}

  @doc "Validate question"
  @spec validate_question(term()) :: :ok | {:error, Error.t()}
  def validate_question(question) when is_binary(question) and byte_size(question) > 0, do: :ok
  def validate_question(""), do: {:error, %Error{message: "question is required", code: nil}}
  def validate_question(nil), do: {:error, %Error{message: "question is required", code: nil}}

  def validate_question(_),
    do: {:error, %Error{message: "question must be a non-empty string", code: nil}}

  @doc "Validate poll options"
  @spec validate_options(term()) :: :ok | {:error, Error.t()}
  def validate_options(options) when is_list(options) and length(options) >= 2, do: :ok

  def validate_options(options) when is_list(options),
    do: {:error, %Error{message: "Poll must have at least 2 options", code: nil}}

  def validate_options(_), do: {:error, %Error{message: "options must be a list", code: nil}}

  @doc "Build URL for create poll endpoint"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base_url = get_service_url(session, :group) <> "/api/poll/create"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    build_url(session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t(), [String.t()], String.t(), keyword()) :: map()
  def build_params(group_id, question, options, imei, opts \\ []) do
    %{
      group_id: group_id,
      question: question,
      options: options,
      expired_time: Keyword.get(opts, :expired_time, 0),
      pinAct: false,
      allow_multi_choices: !!Keyword.get(opts, :allow_multi_choices, false),
      allow_add_new_option: !!Keyword.get(opts, :allow_add_new_option, false),
      is_hide_vote_preview: !!Keyword.get(opts, :hide_vote_preview, false),
      is_anonymous: !!Keyword.get(opts, :is_anonymous, false),
      poll_type: 0,
      src: 1,
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
      is_anonymous: data["is_anonymous"] || data[:is_anonymous]
    }
  end

  defp transform_poll_options(options) when is_list(options) do
    Enum.map(options, fn opt ->
      %{
        option_id: opt["option_id"] || opt[:option_id],
        content: opt["content"] || opt[:content],
        vote_count: opt["vote_count"] || opt[:vote_count] || 0
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
