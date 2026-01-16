defmodule ZcaEx.Api.Endpoints.ChangeGroupAvatarTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.ChangeGroupAvatar
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

  describe "build_params/4" do
    test "builds params with default dimensions", %{credentials: credentials} do
      params = ChangeGroupAvatar.build_params("group123", credentials)

      assert params.grid == "group123"
      assert params.avatarSize == 120
      assert params.imei == credentials.imei
      assert params.originWidth == 1080
      assert params.originHeight == 1080
      assert String.starts_with?(params.clientId, "ggroup123")
    end

    test "builds params with custom dimensions", %{credentials: credentials} do
      params = ChangeGroupAvatar.build_params("group123", credentials, 800, 600)

      assert params.originWidth == 800
      assert params.originHeight == 600
    end
  end

  describe "build_client_id/1" do
    test "builds client ID with correct prefix" do
      client_id = ChangeGroupAvatar.build_client_id("group123")

      assert String.starts_with?(client_id, "ggroup123")
    end

    test "client ID contains timestamp" do
      client_id = ChangeGroupAvatar.build_client_id("group123")

      assert String.length(client_id) > String.length("ggroup123")
      assert client_id =~ ~r/\d{2}:\d{2} \d{2}\/\d{2}\/\d{4}/
    end
  end

  describe "format_timestamp/1" do
    test "formats timestamp correctly" do
      timestamp = DateTime.to_unix(~U[2024-06-15 14:30:00Z]) * 1000
      result = ChangeGroupAvatar.format_timestamp(timestamp)

      assert result == "14:30 15/06/2024"
    end

    test "pads single digit values with zeros" do
      timestamp = DateTime.to_unix(~U[2024-01-05 09:05:00Z]) * 1000
      result = ChangeGroupAvatar.format_timestamp(timestamp)

      assert result == "09:05 05/01/2024"
    end
  end

  describe "build_url/2" do
    test "builds correct URL with encrypted params", %{session: session} do
      encrypted_params = "encrypted_test_params"
      url = ChangeGroupAvatar.build_url(session, encrypted_params)

      assert url =~ "https://file.zalo.me/api/group/upavatar"
      assert url =~ "params=encrypted_test_params"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "call/5 validation" do
    test "returns error for empty image_data", %{session: session, credentials: credentials} do
      {:error, error} = ChangeGroupAvatar.call(<<>>, "group123", session, credentials)
      assert error.message =~ "Empty image_data"
    end

    test "returns error for nil image_data", %{session: session, credentials: credentials} do
      {:error, error} = ChangeGroupAvatar.call(nil, "group123", session, credentials)
      assert error.message =~ "Missing image_data"
    end

    test "returns error for empty group_id", %{session: session, credentials: credentials} do
      image_data = <<1, 2, 3>>
      {:error, error} = ChangeGroupAvatar.call(image_data, "", session, credentials)
      assert error.message =~ "Missing group_id"
    end

    test "returns error for nil group_id", %{session: session, credentials: credentials} do
      image_data = <<1, 2, 3>>
      {:error, error} = ChangeGroupAvatar.call(image_data, nil, session, credentials)
      assert error.message =~ "Missing group_id"
    end
  end

  describe "default dimensions" do
    test "uses 1080x1080 as default", %{credentials: credentials} do
      params = ChangeGroupAvatar.build_params("group123", credentials)

      assert params.originWidth == 1080
      assert params.originHeight == 1080
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

      image_data = <<1, 2, 3>>

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        ChangeGroupAvatar.call(image_data, "group123", session_no_service, credentials)
      end
    end
  end
end
