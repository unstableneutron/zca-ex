defmodule ZcaEx.Api.Endpoints.RemoveFriendAlias do
  @moduledoc "Remove alias for a friend"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Remove alias for a friend.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - friend_id: Friend's user ID (required)

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), String.t()) ::
          {:ok, :success} | {:error, Error.t()}
  def call(session, credentials, friend_id) do
    with :ok <- validate_friend_id(friend_id) do
      params = build_params(friend_id)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(session, encrypted_params)

          case AccountClient.get(session.uid, url, credentials.user_agent) do
            {:ok, response} ->
              with {:ok, _data} <- Response.parse(response, session.secret_key) do
                {:ok, :success}
              end

            {:error, reason} ->
              {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "Validate friend_id is present"
  @spec validate_friend_id(String.t() | nil) :: :ok | {:error, Error.t()}
  def validate_friend_id(nil), do: {:error, %Error{message: "friend_id is required", code: nil}}
  def validate_friend_id(""), do: {:error, %Error{message: "friend_id is required", code: nil}}
  def validate_friend_id(id) when is_binary(id), do: :ok

  def validate_friend_id(_),
    do: {:error, %Error{message: "friend_id must be a string", code: nil}}

  @doc "Build params for encryption"
  @spec build_params(String.t()) :: map()
  def build_params(friend_id) do
    %{friendId: friend_id}
  end

  @doc "Build URL for remove friend alias endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session) <> "/api/alias/remove"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session) <> "/api/alias/remove"
    Url.build_for_session(base_url, %{}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["alias", Access.at(0)]) do
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for alias"
    end
  end
end
