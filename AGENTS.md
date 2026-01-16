# ZcaEx - Elixir Zalo API Client

## Commands
- **Build/check**: `mix compile`, `mix dialyzer`
- **Format**: `mix format`
- **Test all**: `mix test`
- **Single test**: `mix test test/path/to/file_test.exs:LINE`
- **Test file**: `mix test test/zca_ex/some_test.exs`

## Architecture
- **Main entry**: `lib/zca_ex.ex` - public API facade
- **Account management**: `lib/zca_ex/account/` - GenServer per account (Manager, Supervisor, Credentials, Session)
- **API endpoints**: `lib/zca_ex/api/endpoints/` - REST API wrappers (SendMessage, GetUserInfo, etc.)
- **WebSocket**: `lib/zca_ex/ws/` - real-time connection handling
- **Events**: `lib/zca_ex/events/` - `:pg`-based pub/sub system
- **Phoenix adapter**: `lib/zca_ex/adapters/phoenix_pubsub.ex` - bridges events to Phoenix.PubSub
- **Crypto**: `lib/zca_ex/crypto/` - encryption utilities
- **Test support**: `test/support/`, fixtures in `test/fixtures/`

## Code Style
- Use `@spec` typespecs on all public functions
- Return `{:ok, value} | {:error, ZcaEx.Error.t()}` for fallible operations
- Use `ZcaEx.Error.new/3` or helpers (`.network/2`, `.api/3`, `.auth/2`) for structured errors
- Module aliases at top: `alias ZcaEx.Account.{Credentials, Manager}`
- Format with `mix format` before committing
