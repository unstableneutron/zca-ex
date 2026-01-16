# Find a friend by name and send them a message
# Usage: mix run scripts/find_and_message.exs

alias ZcaEx.Account.{Credentials, Manager}
alias ZcaEx.Account.Supervisor, as: AccountSupervisor
alias ZcaEx.Api.Endpoints.{GetAllFriends, SendMessage}

{:ok, json} = File.read("scripts/credentials.json")
{:ok, map} = Jason.decode(json)
{:ok, credentials} = Credentials.from_map(map)

Application.ensure_all_started(:zca_ex)

case AccountSupervisor.start_link(account_id: :test, credentials: credentials) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

{:ok, session} = Manager.login(:test)
IO.puts("✓ Logged in as UID: #{session.uid}")

{:ok, _} = ZcaEx.CookieJar.Jar.start_link(account_id: session.uid)
ZcaEx.CookieJar.import(session.uid, credentials.cookies)

# Get friends list
{:ok, result} = GetAllFriends.call(session, credentials)
friends = case result do
  list when is_list(list) -> list
  map when is_map(map) -> Map.get(map, "friends") || Map.get(map, :friends) || []
  _ -> []
end
IO.puts("✓ Got #{length(friends)} friends")

# Search for user with keywords in name
# Looking for "doat hon hu cot cuu"
keywords = ["doat", "cot", "cuu", "đoạt", "cốt", "cưu", "hồn"]
matches = Enum.filter(friends, fn f ->
  name = (f["displayName"] || f["zaloName"] || f[:display_name] || f[:zalo_name] || "") |> String.downcase()
  Enum.any?(keywords, &String.contains?(name, &1))
end)

IO.puts("\nFound #{length(matches)} matching friends:")
Enum.each(matches, fn f ->
  uid = f["userId"] || f[:user_id] || f["uid"]
  name = f["displayName"] || f["zaloName"] || f[:display_name] || f[:zalo_name]
  IO.puts("  UID: #{uid}")
  IO.puts("  Name: #{name}")
  IO.puts("")
end)

# Send message to first match
case matches do
  [friend | _] ->
    uid = friend["userId"] || friend[:user_id] || friend["uid"]
    name = friend["displayName"] || friend["zaloName"] || friend[:display_name] || friend[:zalo_name]
    
    IO.puts("\n--- Sending message to #{name} (#{uid}) ---")
    
    message = "Xin chào! Đây là tin nhắn test từ ZcaEx 🎉"
    
    case SendMessage.send(message, uid, :user, session, credentials) do
      {:ok, result} ->
        IO.puts("✓ Message sent!")
        IO.inspect(result, label: "Result")
      {:error, error} ->
        IO.puts("✗ Failed: #{inspect(error)}")
    end
    
  [] ->
    IO.puts("\n⚠ No matching friends found")
end
