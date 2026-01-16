defmodule ZcaEx.Test.Fixtures do
  @moduledoc "Test fixtures for API endpoint tests"

  alias ZcaEx.Account.{Session, Credentials}
  alias ZcaEx.Crypto.AesCbc

  @test_secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  def test_secret_key, do: @test_secret_key

  def build_session(overrides \\ %{}) do
    defaults = %Session{
      uid: "123456789",
      secret_key: @test_secret_key,
      zpw_service_map: %{
        "chat" => ["https://chat.zalo.me"],
        "group" => ["https://groupchat.zalo.me"],
        "reaction" => ["https://reaction.chat.zalo.me"]
      },
      ws_endpoints: [],
      api_type: 30,
      api_version: 645,
      settings: %{},
      login_info: %{},
      extra_ver: %{}
    }

    Map.merge(defaults, overrides)
  end

  def build_credentials(overrides \\ []) do
    defaults = [
      imei: "test-imei-12345",
      user_agent: "Mozilla/5.0 (Test)",
      cookies: "test_cookie=value",
      language: "vi",
      api_type: 30,
      api_version: 665
    ]

    Credentials.new!(Keyword.merge(defaults, overrides))
  end

  def build_success_response(data, secret_key \\ @test_secret_key) do
    encrypted_data = encrypt_response_data(data, secret_key)

    response_body =
      Jason.encode!(%{
        "error_code" => 0,
        "error_message" => "Success",
        "data" => encrypted_data
      })

    %{status: 200, body: response_body, headers: []}
  end

  def build_error_response(code, message) do
    response_body =
      Jason.encode!(%{
        "error_code" => code,
        "error_message" => message
      })

    %{status: 200, body: response_body, headers: []}
  end

  def encrypt_response_data(data, secret_key) when is_map(data) do
    {:ok, key} = Base.decode64(secret_key)
    json = Jason.encode!(data)
    AesCbc.encrypt_base64_key(key, json)
  end
end
