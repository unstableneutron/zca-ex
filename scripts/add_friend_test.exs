# Test adding a friend by phone number
# Usage: mix run scripts/add_friend_test.exs [phone_number]
#
# This script demonstrates both approaches:
# 1. SendFriendRequestByPhone - convenience endpoint (recommended)
# 2. Manual FindUser + SendFriendRequest (for debugging)

defmodule AddFriendTest do
  alias ZcaEx.Account.{Credentials, Manager}
  alias ZcaEx.Account.Supervisor, as: AccountSupervisor
  alias ZcaEx.Api.Endpoints.{FindUser, SendFriendRequest, SendFriendRequestByPhone}

  @credentials_path "scripts/credentials.json"

  def run(phone_number) do
    IO.puts("\n=== Add Friend Test ===\n")

    {:ok, credentials} = load_credentials()
    IO.puts("✓ Loaded credentials")

    account_id = :add_friend_test
    Application.ensure_all_started(:zca_ex)
    
    case AccountSupervisor.start_link(account_id: account_id, credentials: credentials) do
      {:ok, _} -> IO.puts("✓ Account supervisor started")
      {:error, {:already_started, _}} -> IO.puts("✓ Account supervisor already running")
    end

    {:ok, session} = Manager.login(account_id)
    IO.puts("✓ Logged in as UID: #{session.uid}")

    {:ok, _} = ZcaEx.CookieJar.Jar.start_link(account_id: session.uid)
    ZcaEx.CookieJar.import(session.uid, credentials.cookies)

    # Test 1: Use the convenience endpoint (recommended approach)
    IO.puts("\n--- Test 1: SendFriendRequestByPhone (Recommended) ---")
    IO.puts("Phone: #{phone_number}")
    
    case SendFriendRequestByPhone.call(session, credentials, phone_number, message: "Hi from ZcaEx!") do
      {:ok, %{user: user, result: result}} ->
        IO.puts("✓ Friend request sent!")
        IO.puts("  To: #{user.zalo_name || user.display_name}")
        IO.puts("  User ID: #{user.uid}")
        IO.inspect(result, label: "  Result")

      {:error, %{code: :user_id_hidden} = error} ->
        IO.puts("⚠ #{error.message}")
        IO.puts("\nThis is a Zalo API limitation - user's privacy settings hide their ID.")

      {:error, %{code: :user_not_found}} ->
        IO.puts("✗ No user found with this phone number")

      {:error, %{code: 225}} ->
        IO.puts("✓ Already friends with this user")

      {:error, %{code: 222}} ->
        IO.puts("✓ User already sent you a request - your request was treated as acceptance")

      {:error, %{code: 215}} ->
        IO.puts("✗ User may have blocked you")

      {:error, error} ->
        IO.puts("✗ Error: #{inspect(error)}")
    end

    # Test 2: Lookup only (check if we can send before attempting)
    IO.puts("\n--- Test 2: Lookup (Check before sending) ---")
    
    case SendFriendRequestByPhone.lookup(session, credentials, phone_number) do
      {:ok, %{user: user, can_send_request: can_send}} ->
        IO.puts("  Name: #{user.zalo_name || user.display_name || "(none)"}")
        IO.puts("  User ID: #{inspect(user.uid)}")
        IO.puts("  Global ID: #{user.global_id}")
        IO.puts("  Can send request: #{can_send}")

      {:error, error} ->
        IO.puts("✗ Lookup failed: #{inspect(error)}")
    end

    # Test 3: Manual approach (for debugging)
    IO.puts("\n--- Test 3: Manual FindUser + SendFriendRequest ---")
    
    case FindUser.call(session, credentials, phone_number) do
      {:ok, user} ->
        IO.puts("  Found: #{user.zalo_name || user.display_name || "(none)"}")
        IO.puts("  uid: #{inspect(user.uid)}")
        IO.puts("  global_id: #{user.global_id}")
        
        if user.uid != "" do
          case SendFriendRequest.call(session, credentials, user.uid, message: "Test") do
            {:ok, _} -> IO.puts("  ✓ Request sent")
            {:error, e} -> IO.puts("  ✗ #{inspect(e)}")
          end
        else
          IO.puts("  ⚠ Cannot send - user ID is empty")
        end

      {:error, error} ->
        IO.puts("  ✗ Find failed: #{inspect(error)}")
    end

    IO.puts("\n=== Test Complete ===\n")
  end

  defp load_credentials do
    with {:ok, json} <- File.read(@credentials_path),
         {:ok, map} <- Jason.decode(json) do
      Credentials.from_map(map)
    end
  end
end

phone = System.argv() |> List.first() || "0968760020"
AddFriendTest.run(phone)
