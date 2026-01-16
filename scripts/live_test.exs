# Live test script for ZcaEx
#
# Usage:
#   mix run scripts/live_test.exs
#
# This script will:
# 1. Check for existing credentials in scripts/credentials.json
# 2. If not found, start QR login flow (scan with Zalo mobile app)
# 3. Save credentials for future runs
# 4. Login and run basic API tests

defmodule LiveTest do
  @credentials_path "scripts/credentials.json"

  alias ZcaEx.Account.{Credentials, Manager}
  alias ZcaEx.Account.Supervisor, as: AccountSupervisor
  alias ZcaEx.Api.LoginQR

  def run do
    IO.puts("\n=== ZcaEx Live Test ===\n")

    ensure_app_started()

    case load_credentials() do
      {:ok, credentials} ->
        IO.puts("✓ Loaded existing credentials")
        login_and_test(credentials)

      :not_found ->
        IO.puts("No credentials found, starting QR login...")
        qr_login()
    end
  end

  defp ensure_app_started do
    Application.ensure_all_started(:zca_ex)
  end

  # --- Credentials Persistence ---

  defp load_credentials do
    if File.exists?(@credentials_path) do
      case File.read(@credentials_path) do
        {:ok, json} ->
          case Jason.decode(json) do
            {:ok, map} -> Credentials.from_map(map)
            {:error, _} -> :not_found
          end

        {:error, _} ->
          :not_found
      end
    else
      :not_found
    end
  end

  defp save_credentials(credentials) do
    json =
      credentials
      |> Credentials.to_map(include_sensitive?: true)
      |> Jason.encode!(pretty: true)

    File.write!(@credentials_path, json)
    IO.puts("✓ Saved credentials to #{@credentials_path}")
  end

  # --- QR Login Flow ---

  defp qr_login do
    {:ok, pid} = LoginQR.start(self())
    IO.puts("QR login started (PID: #{inspect(pid)})")

    receive_qr_events(pid)
  end

  defp receive_qr_events(pid) do
    receive do
      {:zca_qr_login, %{type: :qr_generated, code: _code, image: image}} ->
        qr_path = "scripts/qr.png"
        File.write!(qr_path, Base.decode64!(image))
        IO.puts("\n✓ QR code saved to #{qr_path}")
        IO.puts("  Open the QR image and scan with your Zalo mobile app")
        IO.puts("  Waiting for scan... (timeout: 2 minutes)\n")
        
        # Try to open the QR image automatically on macOS
        System.cmd("open", [qr_path], stderr_to_stdout: true)
        
        receive_qr_events(pid)

      {:zca_qr_login, %{type: :qr_scanned, display_name: name}} ->
        IO.puts("✓ QR scanned by: #{name}")
        IO.puts("  Please confirm on your phone...")
        receive_qr_events(pid)

      {:zca_qr_login, %{type: :qr_expired}} ->
        IO.puts("✗ QR code expired, retrying...")
        LoginQR.retry(pid)
        receive_qr_events(pid)

      {:zca_qr_login, %{type: :qr_declined}} ->
        IO.puts("✗ Login declined on phone")
        System.halt(1)

      {:zca_qr_login, %{type: :login_complete} = event} ->
        IO.puts("✓ Login complete!")
        handle_login_complete(event)

      {:zca_qr_login, %{type: :login_error, error: error}} ->
        IO.puts("✗ Login error: #{inspect(error)}")
        System.halt(1)

      other ->
        IO.puts("Unknown event: #{inspect(other)}")
        receive_qr_events(pid)
    after
      120_000 ->
        IO.puts("✗ Timeout waiting for QR scan")
        LoginQR.abort(pid)
        System.halt(1)
    end
  end

  defp handle_login_complete(%{cookies: cookies, imei: imei, user_agent: user_agent, user_info: user_info}) do
    IO.puts("  Name: #{user_info.name}")

    credentials = Credentials.new!(
      imei: imei,
      user_agent: user_agent,
      cookies: cookies
    )

    save_credentials(credentials)
    login_and_test(credentials)
  end

  # --- Login and Test ---

  defp login_and_test(credentials) do
    account_id = :test_account

    IO.puts("\nStarting account supervisor...")

    case AccountSupervisor.start_link(account_id: account_id, credentials: credentials) do
      {:ok, _pid} ->
        IO.puts("✓ Account supervisor started")

      {:error, {:already_started, _pid}} ->
        IO.puts("✓ Account supervisor already running")
    end

    IO.puts("Logging in...")

    case Manager.login(account_id) do
      {:ok, session} ->
        IO.puts("✓ Login successful!")
        IO.puts("  UID: #{session.uid}")
        IO.puts("  Services: #{map_size(session.zpw_service_map)} endpoints")

        # Import cookies to the UID-based cookie jar for API calls
        {:ok, _} = ZcaEx.CookieJar.Jar.start_link(account_id: session.uid)
        ZcaEx.CookieJar.import(session.uid, credentials.cookies)

        run_tests(session, credentials)

      {:error, reason} ->
        IO.puts("✗ Login failed: #{inspect(reason)}")
        IO.puts("\nCredentials may be expired. Delete #{@credentials_path} and try again.")
        System.halt(1)
    end
  end

  defp run_tests(session, credentials) do
    IO.puts("\n=== Running API Tests ===\n")

    # Test 1: Fetch own account info
    test_fetch_account_info(session, credentials)

    # Test 2: Get friends list
    friends = test_get_friends(session, credentials)

    # Test 3: Get sticker packs
    test_get_stickers(session, credentials)

    # Test 4: Get all groups
    groups = test_get_all_groups(session, credentials)

    # Test 5: Get group info (if we have groups)
    test_get_group_info(groups, session, credentials)

    # Test 6: Get user info (if we have friends)
    test_get_user_info(friends, session, credentials)

    # Test 7: Get settings
    test_get_settings(session, credentials)

    # Test 8: Get hidden conversations
    test_get_hidden_conversations(session, credentials)

    # Test 9: Get pinned conversations
    test_get_pin_conversations(session, credentials)

    # Test 10: Get archived chats
    test_get_archived_chats(session, credentials)

    # Test 11: Get labels
    test_get_labels(session, credentials)

    # Test 12: Get unread mark
    test_get_unread_mark(session, credentials)

    IO.puts("\n=== All Tests Complete ===\n")
  end

  defp test_fetch_account_info(session, credentials) do
    IO.write("1. Fetching account info... ")

    case ZcaEx.Api.Endpoints.FetchAccountInfo.call(session, credentials) do
      {:ok, info} ->
        IO.puts("✓")
        IO.puts("   Name: #{info.name}")
        IO.puts("   Phone: #{info.phone_number || "(hidden)"}")

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
    end
  end

  defp test_get_friends(session, credentials) do
    IO.write("2. Getting friends list... ")

    case ZcaEx.Api.Endpoints.GetAllFriends.call(session, credentials) do
      {:ok, %{friends: friends}} when is_list(friends) ->
        IO.puts("✓ (#{length(friends)} friends)")
        friends

      {:ok, result} when is_map(result) ->
        friends = Map.get(result, :friends) || Map.get(result, "friends") || []
        IO.puts("✓ (#{length(friends)} friends)")
        friends

      {:ok, friends} when is_list(friends) ->
        IO.puts("✓ (#{length(friends)} friends)")
        friends

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
        []
    end
  end

  defp test_get_stickers(session, credentials) do
    IO.write("3. Getting sticker packs... ")

    # GetStickers.get/3 takes a keyword like "hello" to search for stickers
    case ZcaEx.Api.Endpoints.GetStickers.get("hello", session, credentials) do
      {:ok, result} when is_map(result) ->
        count = length(Map.get(result, :sticker_ids) || Map.get(result, "sticker_ids") || [])
        IO.puts("✓ (#{count} sticker results)")

      {:ok, result} when is_list(result) ->
        IO.puts("✓ (#{length(result)} sticker results)")

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
    end
  end

  defp test_get_all_groups(session, credentials) do
    IO.write("4. Getting all groups... ")

    case ZcaEx.Api.Endpoints.GetAllGroups.call(session, credentials) do
      {:ok, %{grid_ver_map: grid_ver_map}} when is_map(grid_ver_map) ->
        group_ids = Map.keys(grid_ver_map)
        IO.puts("✓ (#{length(group_ids)} groups)")
        group_ids

      {:ok, result} when is_map(result) ->
        grid_ver_map = Map.get(result, :grid_ver_map) || Map.get(result, "gridVerMap") || %{}
        group_ids = Map.keys(grid_ver_map)
        IO.puts("✓ (#{length(group_ids)} groups)")
        group_ids

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
        []
    end
  end

  defp test_get_group_info([], _session, _credentials) do
    IO.puts("5. Getting group info... ⊘ (no groups to test)")
  end

  defp test_get_group_info([group_id | _], session, credentials) do
    IO.write("5. Getting group info (#{group_id})... ")

    case ZcaEx.Api.Endpoints.GetGroupInfo.call(group_id, session, credentials) do
      {:ok, result} when is_map(result) ->
        grid_info_map = Map.get(result, "gridInfoMap") || Map.get(result, :gridInfoMap) || %{}
        
        case Map.get(grid_info_map, group_id) do
          %{"name" => name} -> IO.puts("✓ (name: #{name})")
          _ -> IO.puts("✓")
        end

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
    end
  end

  defp test_get_user_info([], _session, _credentials) do
    IO.puts("6. Getting user info... ⊘ (no friends to test)")
  end

  defp test_get_user_info(friends, session, credentials) do
    # Get first friend's user ID
    friend_id = 
      case List.first(friends) do
        %{user_id: id} -> id
        %{"user_id" => id} -> id
        %{"userId" => id} -> id
        %{userId: id} -> id
        id when is_binary(id) -> id
        _ -> nil
      end

    if friend_id do
      IO.write("6. Getting user info (#{friend_id})... ")

      case ZcaEx.Api.Endpoints.GetUserInfo.call(friend_id, session, credentials) do
        {:ok, result} when is_map(result) ->
          changed = Map.get(result, "changed_profiles") || Map.get(result, :changed_profiles) || %{}
          unchanged = Map.get(result, "unchanged_profiles") || Map.get(result, :unchanged_profiles) || %{}
          IO.puts("✓ (changed: #{map_size(changed)}, unchanged: #{map_size(unchanged)})")

        {:error, error} ->
          IO.puts("✗ #{inspect(error)}")
      end
    else
      IO.puts("6. Getting user info... ⊘ (couldn't extract friend ID)")
    end
  end

  defp test_get_settings(session, credentials) do
    IO.write("7. Getting settings... ")

    case ZcaEx.Api.Endpoints.GetSettings.call(session, credentials) do
      {:ok, settings} when is_map(settings) ->
        # Show a couple of setting values
        online = Map.get(settings, :show_online_status)
        seen = Map.get(settings, :display_seen_status)
        IO.puts("✓ (online_status: #{online || "?"}, seen_status: #{seen || "?"})")

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
    end
  end

  defp test_get_hidden_conversations(session, credentials) do
    IO.write("8. Getting hidden conversations... ")

    case ZcaEx.Api.Endpoints.GetHiddenConversations.call(session, credentials) do
      {:ok, %{threads: threads}} when is_list(threads) ->
        IO.puts("✓ (#{length(threads)} hidden threads)")

      {:ok, result} when is_map(result) ->
        threads = Map.get(result, :threads) || Map.get(result, "threads") || []
        IO.puts("✓ (#{length(threads)} hidden threads)")

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
    end
  end

  defp test_get_pin_conversations(session, credentials) do
    IO.write("9. Getting pinned conversations... ")

    case ZcaEx.Api.Endpoints.GetPinConversations.call(session, credentials) do
      {:ok, result} when is_map(result) ->
        pinned = Map.get(result, :pinned_ids) || Map.get(result, "pinned_ids") || []
        IO.puts("✓ (#{length(pinned)} pinned)")

      {:ok, result} when is_list(result) ->
        IO.puts("✓ (#{length(result)} pinned)")

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
    end
  end

  defp test_get_archived_chats(session, credentials) do
    IO.write("10. Getting archived chats... ")

    case ZcaEx.Api.Endpoints.GetArchivedChatList.call(session, credentials) do
      {:ok, %{items: items}} when is_list(items) ->
        IO.puts("✓ (#{length(items)} archived)")

      {:ok, result} when is_map(result) ->
        items = Map.get(result, :items) || Map.get(result, "items") || []
        IO.puts("✓ (#{length(items)} archived)")

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
    end
  end

  defp test_get_labels(session, credentials) do
    IO.write("11. Getting labels... ")

    case ZcaEx.Api.Endpoints.GetLabels.get(session, credentials) do
      {:ok, %{label_data: labels}} when is_list(labels) ->
        IO.puts("✓ (#{length(labels)} labels)")

      {:ok, result} when is_map(result) ->
        labels = Map.get(result, :label_data) || Map.get(result, "labelData") || []
        IO.puts("✓ (#{length(labels)} labels)")

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
    end
  end

  defp test_get_unread_mark(session, credentials) do
    IO.write("12. Getting unread marks... ")

    case ZcaEx.Api.Endpoints.GetUnreadMark.get(session, credentials) do
      {:ok, result} when is_map(result) ->
        users = Map.get(result, :convs_user) || []
        groups = Map.get(result, :convs_group) || []
        IO.puts("✓ (#{length(users)} user, #{length(groups)} group)")

      {:error, error} ->
        IO.puts("✗ #{inspect(error)}")
    end
  end
end

LiveTest.run()
