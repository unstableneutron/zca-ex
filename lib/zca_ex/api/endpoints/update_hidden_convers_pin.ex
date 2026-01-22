defmodule ZcaEx.Api.Endpoints.UpdateHiddenConversPin do
  @moduledoc "Update the PIN for hidden conversations"

  use ZcaEx.Api.Factory

  alias ZcaEx.Error

  @pin_regex ~r/^\d{4}$/

  @doc """
  Update the PIN for hidden conversations.

  ## Parameters
    - session: Authenticated session
    - credentials: Account credentials
    - pin: 4-digit PIN string (0000-9999)

  ## Returns
    - `{:ok, :success}` on success
    - `{:error, Error.t()}` on failure
  """
  @spec call(Session.t(), Credentials.t(), String.t()) ::
          {:ok, :success} | {:error, Error.t()}
  def call(session, credentials, pin) do
    with :ok <- validate_pin(pin),
         {:ok, service_url} <- get_service_url(session) do
      encrypted_pin = encrypt_pin(pin)
      params = build_params(encrypted_pin, credentials.imei)

      case encrypt_params(session.secret_key, params) do
        {:ok, encrypted_params} ->
          url = build_url(service_url, encrypted_params, session)

          case AccountClient.get(session.uid, url, credentials.user_agent) do
            {:ok, response} ->
              case Response.parse(response, session.secret_key) do
                {:ok, _data} -> {:ok, :success}
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

  @doc "Validate that pin is a 4-digit string"
  @spec validate_pin(any()) :: :ok | {:error, Error.t()}
  def validate_pin(pin) when not is_binary(pin) do
    {:error, Error.new(:api, "PIN must be a string", code: :invalid_input)}
  end

  def validate_pin(pin) do
    if Regex.match?(@pin_regex, pin) do
      :ok
    else
      {:error, Error.new(:api, "PIN must be a 4-digit string (0000-9999)", code: :invalid_input)}
    end
  end

  @doc "Encrypt pin using MD5 hash"
  @spec encrypt_pin(String.t()) :: String.t()
  def encrypt_pin(pin) do
    :crypto.hash(:md5, pin) |> Base.encode16(case: :lower)
  end

  @doc "Build params for encryption"
  @spec build_params(String.t(), String.t()) :: map()
  def build_params(encrypted_pin, imei) do
    %{
      new_pin: encrypted_pin,
      imei: imei
    }
  end

  @doc "Build URL for update hidden convers pin endpoint with encrypted params"
  @spec build_url(String.t(), String.t(), Session.t()) :: String.t()
  def build_url(service_url, encrypted_params, session) do
    base_url = service_url <> "/api/hiddenconvers/update-pin"
    Url.build_for_session(base_url, %{params: encrypted_params}, session)
  end

  @doc "Build base URL without params (for testing)"
  @spec build_base_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def build_base_url(session) do
    case get_service_url(session) do
      {:ok, service_url} ->
        base_url = service_url <> "/api/hiddenconvers/update-pin"
        {:ok, Url.build_for_session(base_url, %{}, session)}

      {:error, _} = error ->
        error
    end
  end

  @spec get_service_url(Session.t()) :: {:ok, String.t()} | {:error, Error.t()}
  defp get_service_url(session) do
    case get_in(session.zpw_service_map, ["conversation"]) do
      [url | _] when is_binary(url) ->
        {:ok, url}

      url when is_binary(url) ->
        {:ok, url}

      _ ->
        {:error, Error.new(:api, "conversation service URL not found", code: :service_not_found)}
    end
  end
end
