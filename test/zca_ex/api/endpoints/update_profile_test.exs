defmodule ZcaEx.Api.Endpoints.UpdateProfileTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.UpdateProfile
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "profile" => ["https://profile.zalo.me"]
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

  describe "build_url/1" do
    test "builds correct URL with session params", %{session: session} do
      url = UpdateProfile.build_url(session)

      assert url =~ "https://profile.zalo.me/api/social/profile/update"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end
  end

  describe "build_params/3" do
    test "builds params with profile data only" do
      profile = %{name: "Test User", dob: "1990-01-15", gender: 1}
      params = UpdateProfile.build_params(profile, %{}, "vi")

      assert params.language == "vi"

      profile_data = Jason.decode!(params.profile)
      assert profile_data["name"] == "Test User"
      assert profile_data["dob"] == "1990-01-15"
      assert profile_data["gender"] == 1

      biz_data = Jason.decode!(params.biz)
      assert biz_data["desc"] == nil
      assert biz_data["cate"] == nil
    end

    test "builds params with profile and biz data" do
      profile = %{name: "Business User", dob: "1985-06-20", gender: 2}

      biz = %{
        description: "My Business",
        category: "Technology",
        address: "123 Main St",
        website: "https://example.com",
        email: "contact@example.com"
      }

      params = UpdateProfile.build_params(profile, biz, "en")

      assert params.language == "en"

      profile_data = Jason.decode!(params.profile)
      assert profile_data["name"] == "Business User"
      assert profile_data["dob"] == "1985-06-20"
      assert profile_data["gender"] == 2

      biz_data = Jason.decode!(params.biz)
      assert biz_data["desc"] == "My Business"
      assert biz_data["cate"] == "Technology"
      assert biz_data["addr"] == "123 Main St"
      assert biz_data["website"] == "https://example.com"
      assert biz_data["email"] == "contact@example.com"
    end

    test "builds params with partial biz data" do
      profile = %{name: "Partial Biz", dob: "2000-12-25", gender: 0}
      biz = %{description: "Just a description"}

      params = UpdateProfile.build_params(profile, biz, "vi")

      biz_data = Jason.decode!(params.biz)
      assert biz_data["desc"] == "Just a description"
      assert biz_data["cate"] == nil
      assert biz_data["addr"] == nil
    end
  end

  describe "validate_profile/1" do
    test "returns :ok for valid profile with name" do
      assert :ok = UpdateProfile.validate_profile(%{name: "Valid Name"})
    end

    test "returns :ok for valid profile with all fields" do
      profile = %{name: "Full Profile", dob: "1990-01-01", gender: 1}
      assert :ok = UpdateProfile.validate_profile(profile)
    end

    test "returns error for empty name" do
      assert {:error, error} = UpdateProfile.validate_profile(%{name: ""})
      assert error.message == "Name must be a non-empty string"
    end

    test "returns error for nil name" do
      assert {:error, error} = UpdateProfile.validate_profile(%{name: nil})
      assert error.message == "Name must be a non-empty string"
    end

    test "returns error for missing name key" do
      assert {:error, error} = UpdateProfile.validate_profile(%{dob: "1990-01-01"})
      assert error.message == "Profile must contain name"
    end

    test "returns error for empty map" do
      assert {:error, error} = UpdateProfile.validate_profile(%{})
      assert error.message == "Profile must contain name"
    end
  end

  describe "call/4 validation" do
    test "returns validation error for empty name", %{session: session, credentials: credentials} do
      profile = %{name: ""}

      assert {:error, error} = UpdateProfile.call(session, credentials, profile)
      assert error.message == "Name must be a non-empty string"
    end

    test "returns validation error for missing name", %{
      session: session,
      credentials: credentials
    } do
      profile = %{dob: "1990-01-15"}

      assert {:error, error} = UpdateProfile.call(session, credentials, profile)
      assert error.message == "Profile must contain name"
    end

    test "raises when service URL not found", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}
      profile = %{name: "Test User", dob: "1990-01-15", gender: 1}

      assert_raise RuntimeError, ~r/Service URL not found/, fn ->
        UpdateProfile.call(session_no_service, credentials, profile)
      end
    end
  end
end
