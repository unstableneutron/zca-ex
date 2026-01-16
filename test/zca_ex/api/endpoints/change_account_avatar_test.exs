defmodule ZcaEx.Api.Endpoints.ChangeAccountAvatarTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.ChangeAccountAvatar
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "file" => ["https://file.zalo.me"]
      },
      api_type: 30,
      api_version: 645
    }

    {:ok, credentials} =
      Credentials.new(
        imei: "test-imei-12345",
        user_agent: "Mozilla/5.0 Test",
        cookies: [%{"name" => "test", "value" => "cookie"}],
        language: "vi"
      )

    {:ok, session: session, credentials: credentials}
  end

  describe "build_params/5" do
    test "builds params with required fields" do
      params = ChangeAccountAvatar.build_params("user123", 800, 600, 48000, "vi")

      assert params.avatarSize == 120
      assert params.language == "vi"
      assert String.starts_with?(params.clientId, "user123")
      assert is_binary(params.metaData)
    end

    test "builds metadata with correct structure" do
      params = ChangeAccountAvatar.build_params("user123", 800, 600, 48000, "en")

      assert params.language == "en"
      metadata = Jason.decode!(params.metaData)
      assert metadata["origin"]["width"] == 800
      assert metadata["origin"]["height"] == 600
      assert metadata["processed"]["width"] == 800
      assert metadata["processed"]["height"] == 600
      assert metadata["processed"]["size"] == 48000
    end
  end

  describe "build_client_id/2" do
    test "builds client ID with uid prefix" do
      timestamp = System.system_time(:millisecond)
      client_id = ChangeAccountAvatar.build_client_id("user123", timestamp)

      assert String.starts_with?(client_id, "user123")
    end

    test "client ID contains timestamp" do
      timestamp = System.system_time(:millisecond)
      client_id = ChangeAccountAvatar.build_client_id("user123", timestamp)

      assert String.length(client_id) > String.length("user123")
      assert client_id =~ ~r/\d{2}:\d{2} \d{2}\/\d{2}\/\d{4}/
    end
  end

  describe "format_timestamp/1" do
    test "formats timestamp correctly" do
      timestamp = DateTime.to_unix(~U[2024-06-15 14:30:00Z]) * 1000
      result = ChangeAccountAvatar.format_timestamp(timestamp)

      assert result == "14:30 15/06/2024"
    end

    test "pads single digit values with zeros" do
      timestamp = DateTime.to_unix(~U[2024-01-05 09:05:00Z]) * 1000
      result = ChangeAccountAvatar.format_timestamp(timestamp)

      assert result == "09:05 05/01/2024"
    end
  end

  describe "build_url/2" do
    test "builds correct URL with encrypted params", %{session: session} do
      encrypted_params = "encrypted_test_params"
      url = ChangeAccountAvatar.build_url(session, encrypted_params)

      assert url =~ "https://file.zalo.me/api/profile/upavatar"
      assert url =~ "params=encrypted_test_params"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "metadata JSON structure" do
    test "contains origin and processed fields" do
      params = ChangeAccountAvatar.build_params("user123", 200, 150, 30000, "vi")
      metadata = Jason.decode!(params.metaData)

      assert metadata["origin"]["width"] == 200
      assert metadata["origin"]["height"] == 150
      assert metadata["processed"]["width"] == 200
      assert metadata["processed"]["height"] == 150
      assert metadata["processed"]["size"] == 30000
    end
  end

  describe "validate_image_data/1" do
    test "returns error for empty image_data" do
      {:error, error} = ChangeAccountAvatar.validate_image_data(<<>>)
      assert error.message =~ "empty"
    end

    test "returns error for nil image_data" do
      {:error, error} = ChangeAccountAvatar.validate_image_data(nil)
      assert error.message =~ "required"
    end

    test "returns error for invalid image_data type" do
      {:error, error} = ChangeAccountAvatar.validate_image_data(123)
      assert error.message =~ "binary"
    end

    test "returns :ok for valid binary" do
      assert :ok = ChangeAccountAvatar.validate_image_data(<<1, 2, 3>>)
    end
  end

  describe "call/4 validation" do
    test "returns error for empty avatar_data", %{session: session, credentials: credentials} do
      {:error, error} = ChangeAccountAvatar.call(session, credentials, <<>>)
      assert error.message =~ "empty"
    end

    test "returns error for nil avatar_data", %{session: session, credentials: credentials} do
      {:error, error} = ChangeAccountAvatar.call(session, credentials, nil)
      assert error.message =~ "required"
    end

    test "returns error for invalid avatar_data type", %{session: session, credentials: credentials} do
      {:error, error} = ChangeAccountAvatar.call(session, credentials, 123)
      assert error.message =~ "binary"
    end
  end

  describe "service URL handling" do
    test "raises when service URL not found", %{credentials: credentials} do
      session_no_service = %Session{
        uid: "123456",
        secret_key: @secret_key,
        zpw_service_map: %{},
        api_type: 30,
        api_version: 645
      }

      avatar_data = <<1, 2, 3>>

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        ChangeAccountAvatar.call(session_no_service, credentials, avatar_data)
      end
    end
  end
end
