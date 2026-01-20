defmodule ZcaEx.Account.ManagerTest do
  use ExUnit.Case, async: true

  describe "get_ws_endpoints parsing (via test helper)" do
    # Since get_ws_endpoints/1 is private, we test the parsing logic by replicating it
    # This mirrors the behavior in Manager.do_login/1

    test "handles list of maps with endpoint key" do
      server_info = %{
        "zpw_ws" => [
          %{"endpoint" => "wss://ws1.chat.zalo.me/ws"},
          %{"endpoint" => "wss://ws2.chat.zalo.me/ws"}
        ]
      }

      result = parse_ws_endpoints(server_info)

      assert result == ["wss://ws1.chat.zalo.me/ws", "wss://ws2.chat.zalo.me/ws"]
    end

    test "handles list of strings" do
      server_info = %{
        "zpw_ws" => [
          "wss://ws1.chat.zalo.me",
          "wss://ws2.chat.zalo.me"
        ]
      }

      result = parse_ws_endpoints(server_info)

      assert result == ["wss://ws1.chat.zalo.me", "wss://ws2.chat.zalo.me"]
    end

    test "handles single string" do
      server_info = %{
        "zpw_ws" => "wss://ws1.chat.zalo.me"
      }

      result = parse_ws_endpoints(server_info)

      assert result == ["wss://ws1.chat.zalo.me"]
    end

    test "returns default for nil zpw_ws" do
      server_info = %{}

      result = parse_ws_endpoints(server_info)

      assert result == ["wss://ws1.chat.zalo.me/ws/v2/webchat/socket"]
    end

    test "returns default for empty list" do
      server_info = %{"zpw_ws" => []}

      result = parse_ws_endpoints(server_info)

      assert result == ["wss://ws1.chat.zalo.me/ws/v2/webchat/socket"]
    end

    test "returns default for invalid type" do
      server_info = %{"zpw_ws" => 123}

      result = parse_ws_endpoints(server_info)

      assert result == ["wss://ws1.chat.zalo.me/ws/v2/webchat/socket"]
    end
  end

  describe "server info error normalization" do
    test "maps HTTP status errors to ZcaEx.Error" do
      error = ZcaEx.Account.Manager.normalize_server_info_error({:ok, %{status: 500}})
      assert %ZcaEx.Error{category: :api, code: 500} = error
    end

    test "maps client errors to ZcaEx.Error" do
      error = ZcaEx.Account.Manager.normalize_server_info_error({:error, :timeout})
      assert %ZcaEx.Error{category: :network, retryable?: true} = error
    end
  end

  # Replicates the private get_ws_endpoints/1 function from Manager
  defp parse_ws_endpoints(server_info) do
    case server_info["zpw_ws"] do
      [%{"endpoint" => _} | _] = ws -> Enum.map(ws, fn e -> e["endpoint"] end)
      [url | _] = ws when is_binary(url) -> ws
      url when is_binary(url) -> [url]
      _ -> ["wss://ws1.chat.zalo.me/ws/v2/webchat/socket"]
    end
  end
end
