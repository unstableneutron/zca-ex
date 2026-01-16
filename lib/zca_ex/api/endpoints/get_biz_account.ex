defmodule ZcaEx.Api.Endpoints.GetBizAccount do
  @moduledoc """
  Get business account information for a friend.

  Note: This API is used for zBusiness accounts.
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get business account information.

  ## Parameters
    - friend_id: The friend ID to get biz account info (non-empty string)
    - session: Authenticated session
    - credentials: Account credentials

  ## Returns
    - `{:ok, %{biz: map() | nil, setting_start_page: map() | nil, pkg_id: integer()}}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec get(String.t(), Session.t(), Credentials.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(friend_id, session, credentials) do
    with :ok <- validate_friend_id(friend_id),
         {:ok, service_url} <- get_service_url(session) do
      params = build_params(friend_id)

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

  defp validate_friend_id(friend_id) when is_binary(friend_id) and byte_size(friend_id) > 0, do: :ok
  defp validate_friend_id(_), do: {:error, Error.new(:api, "friend_id must be a non-empty string", code: :invalid_input)}

  @doc false
  def build_params(friend_id) do
    %{fid: friend_id}
  end

  @doc false
  def build_url(service_url, session) do
    base_url = service_url <> "/api/social/friend/get-bizacc"
    Url.build_for_session(base_url, %{}, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["profile"]) do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, Error.new(:api, "profile service URL not found", code: :service_not_found)}
    end
  end

  defp transform_response(data) when is_map(data) do
    %{
      biz: data["biz"] || data[:biz],
      setting_start_page: data["setting_start_page"] || data[:setting_start_page],
      pkg_id: data["pkgId"] || data[:pkgId]
    }
  end
end
