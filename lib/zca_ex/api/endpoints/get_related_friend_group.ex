defmodule ZcaEx.Api.Endpoints.GetRelatedFriendGroup do
  @moduledoc "Get related friend groups (zBusiness feature)"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get related friend groups for given friend IDs.

  ## Parameters
    - friend_ids: Single friend ID string or list of friend ID strings
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{group_relateds: map}}` on success where map is friendId -> [groupIds]
    - `{:error, Error.t()}` on failure
  """
  @spec get(String.t() | [String.t()], Session.t(), Credentials.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def get(friend_ids, session, credentials) do
    friend_ids_list = normalize_friend_ids(friend_ids)

    with :ok <- validate_friend_ids(friend_ids_list),
         {:ok, service_url} <- get_service_url(session),
         {:ok, params} <- build_params(friend_ids_list, credentials.imei) do
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

  @doc "Normalize friend_ids to list"
  @spec normalize_friend_ids(String.t() | [String.t()]) :: [String.t()]
  def normalize_friend_ids(friend_id) when is_binary(friend_id), do: [friend_id]
  def normalize_friend_ids(friend_ids) when is_list(friend_ids), do: friend_ids
  def normalize_friend_ids(_), do: []

  @doc "Validate friend_ids list"
  @spec validate_friend_ids([String.t()]) :: :ok | {:error, Error.t()}
  def validate_friend_ids([]) do
    {:error, Error.new(:api, "friend_ids must not be empty", code: :invalid_input)}
  end

  def validate_friend_ids(friend_ids) when is_list(friend_ids) do
    if Enum.all?(friend_ids, &valid_friend_id?/1) do
      :ok
    else
      {:error, Error.new(:api, "all friend_ids must be non-empty strings", code: :invalid_input)}
    end
  end

  defp valid_friend_id?(id), do: is_binary(id) and id != ""

  @doc "Build URL for get related friend group endpoint"
  @spec build_url(String.t(), Session.t()) :: String.t()
  def build_url(service_url, session) do
    base_url = service_url <> "/api/friend/group/related"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build base URL (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, service_url} ->
        {:ok, build_url(service_url, session)}

      {:error, _} = error ->
        error
    end
  end

  @doc "Build params for encryption"
  @spec build_params([String.t()], String.t()) :: {:ok, map()} | {:error, Error.t()}
  def build_params(friend_ids, imei) do
    case Jason.encode(friend_ids) do
      {:ok, json} ->
        {:ok, %{friend_ids: json, imei: imei}}

      {:error, reason} ->
        {:error,
         Error.new(:api, "Failed to encode friend_ids: #{inspect(reason)}", code: :invalid_input)}
    end
  end

  @doc "Transform response data"
  @spec transform_response(map()) :: map()
  def transform_response(data) when is_map(data) do
    group_relateds =
      data["groupRelateds"] || data[:groupRelateds] ||
        data["group_relateds"] || data[:group_relateds] || %{}

    %{
      group_relateds: group_relateds
    }
  end

  @spec get_service_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["friend"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "friend service URL not found", code: :service_not_found)}
    end
  end
end
