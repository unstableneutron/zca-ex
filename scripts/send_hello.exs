# Send a hello message to a friend
# Usage: mix run scripts/send_hello.exs

alias ZcaEx.Account.{Credentials, Manager}
alias ZcaEx.Account.Supervisor, as: AccountSupervisor
alias ZcaEx.Api.Endpoints.SendMessage
alias ZcaEx.CookieJar

# Friend's UID from the pending request
friend_uid = "1377157535122616717"

# Current timestamp
timestamp = DateTime.utc_now() |> DateTime.to_string()
message = "Hello! 👋 Current timestamp: #{timestamp}"

IO.puts("Loading credentials...")
{:ok, json} = File.read("scripts/credentials.json")
{:ok, map} = Jason.decode(json)
{:ok, credentials} = Credentials.from_map(map)

IO.puts("Starting application...")
Application.ensure_all_started(:zca_ex)

IO.puts("Starting account supervisor...")
account_id = "sender"
case AccountSupervisor.start_link(account_id: account_id, credentials: credentials) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

IO.puts("Logging in...")
{:ok, session} = Manager.login(account_id)
IO.puts("✓ Logged in as UID: #{session.uid}")

# SendMessage.send uses creds.imei as account_id for cookies, so we need to start a CookieJar for it
IO.puts("Setting up cookies for IMEI: #{credentials.imei}...")
case CookieJar.start_link(account_id: credentials.imei, cookies: credentials.cookies) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

IO.puts("\nSending message to #{friend_uid}...")
IO.puts("Message: #{message}")

case SendMessage.send(message, friend_uid, :user, session, credentials) do
  {:ok, result} ->
    IO.puts("\n✅ Message sent successfully!")
    IO.puts("Result: #{inspect(result)}")
    
  {:error, error} ->
    IO.puts("\n❌ Failed to send message")
    IO.puts("Error: #{inspect(error)}")
end
