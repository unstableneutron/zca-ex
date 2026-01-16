defmodule ZcaEx.Api.Endpoints.SendFriendRequest do
  @moduledoc "Send a friend request to a user"

  use ZcaEx.Api.Factory

  alias ZcaEx.HTTP.AccountClient
  alias ZcaEx.Error

  @doc """
  Send a friend request to a user.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - user_id: Target user ID (required)
    - opts: Options
      - `:message` - Message to send with the request (optional, defaults to "")

  ## Returns
    - `{:ok, map()}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def call(session, credentials, user_id, opts \\ []) do
    case validate_user_id(user_id) do
      :ok ->
        message = Keyword.get(opts, :message, "") |> to_string_safe()
        params = build_params(credentials.imei, user_id, message, credentials.language)

        case encrypt_params(session.secret_key, params) do
          {:ok, encrypted_params} ->
            url = build_url(session, encrypted_params)

            case AccountClient.post(session.uid, url, "", credentials.user_agent) do
              {:ok, response} ->
                Response.parse(response, session.secret_key)

              {:error, reason} ->
                {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
            end

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Validate user_id is non-empty"
  @spec validate_user_id(term()) :: :ok | {:error, Error.t()}
  def validate_user_id(nil), do: {:error, %Error{message: "User ID is required", code: nil}}
  def validate_user_id(""), do: {:error, %Error{message: "User ID cannot be empty", code: nil}}
  def validate_user_id(id) when is_binary(id), do: :ok
  def validate_user_id(_), do: {:error, %Error{message: "User ID must be a string", code: nil}}

  @doc "Build URL for send friend request endpoint with encrypted params"
  @spec build_url(Session.t(), String.t()) :: String.t()
  def build_url(session, encrypted_params) do
    base_url = get_service_url(session) <> "/api/friend/sendreq"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: String.t()
  def build_base_url(session) do
    base_url = get_service_url(session) <> "/api/friend/sendreq"
    Url.build_for_session(base_url, %{}, session)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t(), String.t(), String.t()) :: map()
  def build_params(imei, user_id, message \\ "", language \\ "vi") do
    %{
      toid: user_id,
      msg: message,
      reqsrc: 30,
      imei: imei,
      language: language,
      srcParams: Jason.encode!(%{uidTo: user_id})
    }
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["friend", Access.at(0)]) do
      url when is_binary(url) -> url
      _ -> raise "Service URL not found for friend"
    end
  end

  defp to_string_safe(nil), do: ""
  defp to_string_safe(val) when is_binary(val), do: val
  defp to_string_safe(val), do: to_string(val)
end
