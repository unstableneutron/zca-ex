defmodule ZcaEx.Api.Endpoints.GetUnreadMark do
  @moduledoc """
  Get unread marks for all conversations.

  ## Notes
  - Returns both user (1:1) and group conversation unread marks
  """

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @doc """
  Get unread marks for all conversations.

  ## Parameters
    - `session` - The authenticated session
    - `credentials` - Account credentials

  ## Returns
    - `{:ok, %{convs_group: list(), convs_user: list(), status: integer()}}` on success
    - `{:error, ZcaEx.Error.t()}` on failure
  """
  @spec get(Session.t(), Credentials.t()) ::
          {:ok, %{convs_group: list(), convs_user: list(), status: integer() | nil}}
          | {:error, Error.t()}
  def get(session, credentials) do
    params = build_params()

    case encrypt_params(session.secret_key, params) do
      {:ok, encrypted_params} ->
        url = build_url(session, encrypted_params)

        case AccountClient.get(session.uid, url, credentials.user_agent) do
          {:ok, resp} ->
            Response.parse(resp, session.secret_key)
            |> transform_response()

          {:error, reason} ->
            {:error, Error.new(:network, "Request failed: #{inspect(reason)}", reason: reason)}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc false
  def build_params do
    %{}
  end

  @doc false
  def build_url(session, encrypted_params) do
    service_url = get_service_url(session)
    query_params = %{"params" => encrypted_params}
    Url.build_for_session("#{service_url}/api/conv/getUnreadMark", query_params, session)
  end

  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["conversation"]) do
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> raise "conversation service URL not found"
    end
  end

  defp transform_response({:ok, data}) when is_map(data) do
    {:ok,
     %{
       convs_group: data["convsGroup"] || data[:convsGroup] || [],
       convs_user: data["convsUser"] || data[:convsUser] || [],
       status: data["status"] || data[:status]
     }}
  end

  defp transform_response({:ok, data}) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed} -> transform_response({:ok, parsed})
      {:error, _} -> {:ok, %{convs_group: [], convs_user: [], status: nil}}
    end
  end

  defp transform_response({:error, _} = error), do: error
end
