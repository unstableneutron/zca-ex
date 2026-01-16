defmodule ZcaEx.Account.SessionTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Account.Session

  describe "Session.to_map/2" do
    test "excludes secret_key when include_sensitive?: false" do
      session = %Session{
        uid: "123456",
        secret_key: "super-secret-key",
        zpw_service_map: %{"chat" => "https://chat.zalo.me"},
        ws_endpoints: ["wss://ws1.chat.zalo.me"],
        api_type: 30,
        api_version: 645,
        settings: %{"theme" => "dark"},
        login_info: %{"displayName" => "Test User"},
        extra_ver: %{"ver" => "1.0"}
      }

      map = Session.to_map(session, include_sensitive?: false)

      assert map["uid"] == "123456"
      assert map["zpw_service_map"] == %{"chat" => "https://chat.zalo.me"}
      assert map["ws_endpoints"] == ["wss://ws1.chat.zalo.me"]
      assert map["api_type"] == 30
      assert map["api_version"] == 645
      assert map["settings"] == %{"theme" => "dark"}
      assert map["login_info"] == %{"displayName" => "Test User"}
      assert map["extra_ver"] == %{"ver" => "1.0"}
      refute Map.has_key?(map, "secret_key")
    end

    test "includes secret_key when include_sensitive?: true" do
      session = %Session{
        uid: "123456",
        secret_key: "super-secret-key",
        zpw_service_map: %{},
        ws_endpoints: []
      }

      map = Session.to_map(session, include_sensitive?: true)

      assert map["uid"] == "123456"
      assert map["secret_key"] == "super-secret-key"
    end

    test "defaults to include_sensitive?: false" do
      session = %Session{
        uid: "123456",
        secret_key: "super-secret-key",
        zpw_service_map: %{},
        ws_endpoints: []
      }

      map = Session.to_map(session)

      refute Map.has_key?(map, "secret_key")
    end
  end

  describe "Session.from_map/1" do
    test "parses map with atom keys" do
      map = %{
        uid: "123456",
        secret_key: "super-secret-key",
        zpw_service_map: %{"chat" => "https://chat.zalo.me"},
        ws_endpoints: ["wss://ws1.chat.zalo.me"],
        api_type: 31,
        api_version: 700,
        settings: %{"theme" => "dark"},
        login_info: %{"displayName" => "Test User"},
        extra_ver: %{"ver" => "1.0"}
      }

      assert {:ok, session} = Session.from_map(map)
      assert session.uid == "123456"
      assert session.secret_key == "super-secret-key"
      assert session.zpw_service_map == %{"chat" => "https://chat.zalo.me"}
      assert session.ws_endpoints == ["wss://ws1.chat.zalo.me"]
      assert session.api_type == 31
      assert session.api_version == 700
      assert session.settings == %{"theme" => "dark"}
      assert session.login_info == %{"displayName" => "Test User"}
      assert session.extra_ver == %{"ver" => "1.0"}
    end

    test "parses map with string keys" do
      map = %{
        "uid" => "123456",
        "secret_key" => "super-secret-key",
        "zpw_service_map" => %{"chat" => "https://chat.zalo.me"},
        "ws_endpoints" => ["wss://ws1.chat.zalo.me"],
        "api_type" => 31,
        "api_version" => 700,
        "settings" => %{"theme" => "dark"},
        "login_info" => %{"displayName" => "Test User"},
        "extra_ver" => %{"ver" => "1.0"}
      }

      assert {:ok, session} = Session.from_map(map)
      assert session.uid == "123456"
      assert session.secret_key == "super-secret-key"
      assert session.zpw_service_map == %{"chat" => "https://chat.zalo.me"}
      assert session.ws_endpoints == ["wss://ws1.chat.zalo.me"]
      assert session.api_type == 31
      assert session.api_version == 700
    end

    test "converts integer uid to string" do
      map = %{
        "uid" => 123456,
        "secret_key" => "secret",
        "zpw_service_map" => %{}
      }

      assert {:ok, session} = Session.from_map(map)
      assert session.uid == "123456"
    end

    test "uses defaults for optional fields" do
      map = %{
        "uid" => "123456",
        "secret_key" => "secret",
        "zpw_service_map" => %{}
      }

      assert {:ok, session} = Session.from_map(map)
      assert session.ws_endpoints == []
      assert session.api_type == 30
      assert session.api_version == 645
      assert session.settings == nil
      assert session.login_info == nil
      assert session.extra_ver == nil
    end

    test "returns error for missing uid" do
      map = %{
        "secret_key" => "secret",
        "zpw_service_map" => %{}
      }

      assert {:error, {:missing_required, :uid}} = Session.from_map(map)
    end

    test "returns error for missing secret_key" do
      map = %{
        "uid" => "123456",
        "zpw_service_map" => %{}
      }

      assert {:error, {:missing_required, :secret_key}} = Session.from_map(map)
    end

    test "returns error for missing zpw_service_map" do
      map = %{
        "uid" => "123456",
        "secret_key" => "secret"
      }

      assert {:error, {:missing_required, :zpw_service_map}} = Session.from_map(map)
    end
  end

  describe "Session.from_map!/1" do
    test "returns session for valid map" do
      map = %{
        "uid" => "123456",
        "secret_key" => "secret",
        "zpw_service_map" => %{}
      }

      session = Session.from_map!(map)
      assert session.uid == "123456"
    end

    test "raises ArgumentError for missing required fields" do
      map = %{"uid" => "123456"}

      assert_raise ArgumentError, ~r/Invalid session map/, fn ->
        Session.from_map!(map)
      end
    end
  end

  describe "roundtrip serialization" do
    test "to_map |> from_map preserves data" do
      original = %Session{
        uid: "123456",
        secret_key: "super-secret-key",
        zpw_service_map: %{"chat" => "https://chat.zalo.me"},
        ws_endpoints: ["wss://ws1.chat.zalo.me", "wss://ws2.chat.zalo.me"],
        api_type: 31,
        api_version: 700,
        settings: %{"theme" => "dark"},
        login_info: %{"displayName" => "Test User", "avatar" => "https://avatar.url"},
        extra_ver: %{"ver" => "1.0"}
      }

      map = Session.to_map(original, include_sensitive?: true)
      assert {:ok, restored} = Session.from_map(map)

      assert restored.uid == original.uid
      assert restored.secret_key == original.secret_key
      assert restored.zpw_service_map == original.zpw_service_map
      assert restored.ws_endpoints == original.ws_endpoints
      assert restored.api_type == original.api_type
      assert restored.api_version == original.api_version
      assert restored.settings == original.settings
      assert restored.login_info == original.login_info
      assert restored.extra_ver == original.extra_ver
    end
  end

  describe "Session.from_login_response/1" do
    test "creates session from login response" do
      data = %{
        "uid" => 123456,
        "zpw_enk" => "secret-key",
        "zpw_service_map_v3" => %{"chat" => "https://chat.zalo.me"},
        "settings" => %{"theme" => "dark"},
        "isNewAccount" => false,
        "avatar" => "https://avatar.url",
        "displayName" => "Test User",
        "phoneNumber" => "0123456789",
        "extra_ver" => %{"ver" => "1.0"}
      }

      session = Session.from_login_response(data)

      assert session.uid == "123456"
      assert session.secret_key == "secret-key"
      assert session.zpw_service_map == %{"chat" => "https://chat.zalo.me"}
      assert session.settings == %{"theme" => "dark"}
      assert session.extra_ver == %{"ver" => "1.0"}
      assert session.login_info["displayName"] == "Test User"
      assert session.login_info["avatar"] == "https://avatar.url"
    end
  end
end
