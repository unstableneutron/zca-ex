defmodule ZcaEx.Api.Endpoints.GetQR do
  @moduledoc """
  Get QR code URLs for users.

  ## Example

      GetQR.get("user_id", session, creds)
      # => {:ok, %{"user_id" => "https://qr.zalo.me/..."}}

      GetQR.get(["user1", "user2"], session, creds)
      # => {:ok, %{"user1" => "...", "user2" => "..."}}
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @type qr_response :: %{String.t() => String.t()}

  @doc "Get QR code URLs for one or more users"
  @spec get(String.t() | [String.t()], Session.t(), Credentials.t()) ::
          {:ok, qr_response()} | {:error, Error.t()}
  def get(user_ids, session, credentials) when is_binary(user_ids) do
    get([user_ids], session, credentials)
  end

  def get(user_ids, session, credentials) when is_list(user_ids) do
    with :ok <- validate_user_ids(user_ids) do
      url = build_url(session)
      params = build_params(user_ids)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          body = build_form_body(%{params: encrypted_params})

          case AccountClient.post(credentials.imei, url, body, credentials.user_agent) do
            {:ok, response} ->
              Response.parse(response, session.secret_key)
              |> extract_data()

            {:error, reason} ->
              {:error, %Error{message: "Request failed: #{inspect(reason)}", code: nil}}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "Build the get QR URL"
  @spec build_url(Session.t()) :: String.t()
  def build_url(session) do
    base = get_in(session.zpw_service_map, ["friend", Access.at(0)]) <> "/api/friend/mget-qr"
    Url.build(base, %{}, nretry: 0, api_type: session.api_type, version: session.api_version)
  end

  @doc "Build API params"
  @spec build_params([String.t()]) :: map()
  def build_params(user_ids) do
    %{fids: user_ids}
  end

  defp validate_user_ids([]), do: {:error, %Error{message: "Missing user IDs", code: nil}}
  defp validate_user_ids(ids) when is_list(ids), do: :ok

  defp extract_data({:ok, %{"data" => data}}) when is_map(data), do: {:ok, data}
  defp extract_data({:ok, data}) when is_map(data), do: {:ok, data}
  defp extract_data({:error, _} = error), do: error
end
