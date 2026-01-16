# API Endpoints

All endpoints live in `ZcaEx.Api.Endpoints.*` and follow a consistent pattern.

## Structure

Each endpoint module:
1. Accepts `Session` and `Credentials` as arguments
2. Builds the request URL from `session.zpw_service_map`
3. Signs and encrypts parameters via `Api.Factory`
4. Executes via `HTTP.AccountClient`
5. Decrypts response via `Api.Response`
6. Returns `{:ok, result}` or `{:error, ZcaEx.Error.t()}`

## Key Modules

| Module | Purpose |
|--------|---------|
| `HTTP.AccountClient` | Per-account HTTP client with cookie management |
| `HTTP.Client` | Low-level HTTP via Req library |
| `Api.Factory` | Macro for building endpoints (encryption, signing) |
| `Api.Response` | Response decryption and error handling |
| `Api.Url` | URL construction from service maps |

## Categories

### Messaging

| Module | Function | Description |
|--------|----------|-------------|
| `SendMessage` | `send/5` | Send text message |
| `SendSticker` | `send/5` | Send sticker |
| `SendLink` | `send/5` | Send link with preview |
| `ForwardMessage` | `forward/5` | Forward message |
| `UndoMessage` | `undo/5` | Recall sent message |
| `DeleteMessage` | `delete/5` | Delete message |

### Users & Friends

| Module | Function | Description |
|--------|----------|-------------|
| `GetUserInfo` | `get/3` | Fetch user profile |
| `GetAllFriends` | `list/2` | List all friends |
| `FindUser` | `find/3` | Search users |
| `SendFriendRequest` | `send/4` | Send friend request |
| `BlockUser` | `block/3` | Block user |

### Groups

| Module | Function | Description |
|--------|----------|-------------|
| `GetGroupInfo` | `get/3` | Fetch group details |
| `CreateGroup` | `create/4` | Create new group |
| `AddUserToGroup` | `add/4` | Add member |
| `ChangeGroupName` | `change/4` | Rename group |
| `AddGroupDeputy` | `add/4` | Promote to deputy |

### Profile & Settings

| Module | Function | Description |
|--------|----------|-------------|
| `GetSettings` | `get/2` | Fetch account settings |
| `UpdateProfile` | `update/3` | Update profile info |
| `ChangeAccountAvatar` | `change/3` | Update avatar |
| `UpdateActiveStatus` | `update/3` | Set online status |

## Usage Example

```elixir
alias ZcaEx.Api.Endpoints.SendMessage

# Get session after login
session = ZcaEx.get_session("my_account")
credentials = ZcaEx.Account.Manager.get_credentials("my_account")

{:ok, result} = SendMessage.send(
  "Hello!",           # message
  "user_id_123",      # thread_id
  :user,              # :user or :group
  session,
  credentials
)
```

## Building Custom Endpoints

Endpoints use `Api.Factory` for consistent structure:

```elixir
defmodule ZcaEx.Api.Endpoints.MyEndpoint do
  use ZcaEx.Api.Factory

  @impl true
  def call(params, session, credentials) do
    url = Api.Url.build(session, :some_service, "/path")

    with {:ok, encrypted} <- encrypt_params(params, session),
         {:ok, signed} <- sign_request(encrypted, credentials),
         {:ok, response} <- AccountClient.post(url, signed, credentials.account_id),
         {:ok, data} <- Api.Response.parse(response, session) do
      {:ok, data}
    end
  end
end
```

## Error Handling

All endpoints return `{:error, %ZcaEx.Error{}}` on failure. See [Error Handling](ERROR_HANDLING.md) for details.

```elixir
case SendMessage.send(...) do
  {:ok, result} ->
    handle_success(result)

  {:error, %ZcaEx.Error{category: :api, code: code}} ->
    handle_api_error(code)

  {:error, %ZcaEx.Error{category: :network, retryable?: true}} ->
    retry_later()

  {:error, %ZcaEx.Error{category: :auth}} ->
    re_authenticate()
end
```
