# Import credentials from browser/extension
#
# Usage:
#   1. Login to chat.zalo.me in your browser
#   2. Use ZaloDataExtractor extension OR manually get cookies from DevTools
#   3. Create scripts/browser_credentials.json with:
#      {
#        "imei": "your-imei",
#        "cookies": [...cookie array from extension...],
#        "user_agent": "your browser user agent"
#      }
#   4. Run: mix run scripts/import_credentials.exs
#
# To get cookies manually from browser DevTools:
#   1. Open chat.zalo.me, press F12
#   2. Go to Application > Cookies > https://chat.zalo.me
#   3. Copy all cookies as JSON

defmodule ImportCredentials do
  @browser_creds_path "scripts/browser_credentials.json"
  @output_path "scripts/credentials.json"

  alias ZcaEx.Account.Credentials

  def run do
    IO.puts("\n=== Import Browser Credentials ===\n")

    case File.read(@browser_creds_path) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, data} ->
            import_and_test(data)

          {:error, reason} ->
            IO.puts("✗ Failed to parse JSON: #{inspect(reason)}")
        end

      {:error, :enoent} ->
        IO.puts("✗ File not found: #{@browser_creds_path}")
        IO.puts("")
        IO.puts("Please create #{@browser_creds_path} with your browser credentials:")
        IO.puts(~S"""
        {
          "imei": "your-device-imei",
          "cookies": [
            {"name": "cookie_name", "value": "cookie_value", "domain": ".zalo.me"},
            ...
          ],
          "user_agent": "Mozilla/5.0 ..."
        }
        """)
        IO.puts("")
        IO.puts("You can get these from:")
        IO.puts("  - ZaloDataExtractor browser extension")
        IO.puts("  - Browser DevTools (Application > Cookies)")
    end
  end

  defp import_and_test(data) do
    IO.puts("Importing credentials...")

    case Credentials.from_map(data) do
      {:ok, credentials} ->
        IO.puts("✓ Credentials parsed successfully")
        IO.puts("  IMEI: #{String.slice(credentials.imei, 0, 8)}...")
        IO.puts("  Cookies: #{length(credentials.cookies)} items")

        # Save to standard location
        json =
          credentials
          |> Credentials.to_map(include_sensitive?: true)
          |> Jason.encode!(pretty: true)

        File.write!(@output_path, json)
        IO.puts("✓ Saved to #{@output_path}")

        # Now test login
        test_login(credentials)

      {:error, reason} ->
        IO.puts("✗ Invalid credentials: #{inspect(reason)}")
    end
  end

  defp test_login(credentials) do
    IO.puts("\nTesting login...")

    Application.ensure_all_started(:zca_ex)

    account_id = :imported_account

    case ZcaEx.Account.Supervisor.start_link(account_id: account_id, credentials: credentials) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    case ZcaEx.Account.Manager.login(account_id) do
      {:ok, session} ->
        IO.puts("✓ Login successful!")
        IO.puts("  UID: #{session.uid}")
        IO.puts("  Services: #{map_size(session.zpw_service_map)} endpoints")

        # Quick test
        IO.puts("\nFetching account info...")
        case ZcaEx.Api.Endpoints.FetchAccountInfo.call(session, credentials) do
          {:ok, info} ->
            IO.puts("✓ Account: #{info.name}")
            IO.puts("\n=== Import Complete ===\n")
            IO.puts("You can now run: mix run scripts/live_test.exs")

          {:error, error} ->
            IO.puts("✗ API test failed: #{inspect(error)}")
        end

      {:error, reason} ->
        IO.puts("✗ Login failed: #{inspect(reason)}")
        IO.puts("\nCredentials may be expired or invalid.")
    end
  end
end

ImportCredentials.run()
