# Error Handling

ZcaEx uses structured errors via `ZcaEx.Error` for consistent error handling across all operations.

## Error Structure

```elixir
%ZcaEx.Error{
  category: :network | :api | :crypto | :auth | :websocket | :unknown,
  code: integer() | nil,        # API error code (if applicable)
  message: String.t(),          # Human-readable message
  reason: term(),               # Original error/exception
  retryable?: boolean(),        # Safe to retry?
  details: map()                # Additional context
}
```

## Error Categories

| Category | Description | Retryable? |
|----------|-------------|------------|
| `:network` | Connection failures, timeouts | Yes |
| `:api` | Zalo API returned an error | Depends on code |
| `:crypto` | Encryption/decryption failed | No |
| `:auth` | Authentication failed | No |
| `:websocket` | WebSocket connection issues | Yes |
| `:unknown` | Unexpected errors | No |

## Creating Errors

```elixir
# Generic
ZcaEx.Error.new(:network, "Connection timeout", reason: :timeout)

# Category-specific helpers
ZcaEx.Error.network("Connection refused", reason: :econnrefused)
ZcaEx.Error.api(401, "Session expired")
ZcaEx.Error.auth("Invalid credentials")
ZcaEx.Error.crypto("Decryption failed", reason: :bad_padding)
ZcaEx.Error.websocket("Connection lost")
```

## Normalizing External Errors

`ZcaEx.Error.normalize/1` converts external exceptions to `ZcaEx.Error`:

```elixir
ZcaEx.Error.normalize(%Mint.TransportError{reason: :timeout})
# => %ZcaEx.Error{category: :network, message: "Transport error: :timeout"}

ZcaEx.Error.normalize(%Jason.DecodeError{...})
# => %ZcaEx.Error{category: :crypto, message: "JSON decode error: ..."}
```

## Handling Errors

```elixir
case ZcaEx.Api.Endpoints.SendMessage.send(...) do
  {:ok, result} ->
    # Success
    process_result(result)

  {:error, %ZcaEx.Error{category: :network, retryable?: true} = error} ->
    # Network issue - safe to retry
    Logger.warning("Network error: #{error.message}")
    schedule_retry()

  {:error, %ZcaEx.Error{category: :api, code: 401}} ->
    # Session expired
    re_login()

  {:error, %ZcaEx.Error{category: :api, code: code}} ->
    # Other API error
    Logger.error("API error #{code}")

  {:error, %ZcaEx.Error{category: :auth}} ->
    # Bad credentials
    notify_user_reauth_needed()

  {:error, error} ->
    # Catch-all
    Logger.error("Unexpected: #{Exception.message(error)}")
end
```

## Checking Retryability

```elixir
error = ZcaEx.Error.network("Timeout")
ZcaEx.Error.retryable?(error)  # => true

error = ZcaEx.Error.auth("Invalid")
ZcaEx.Error.retryable?(error)  # => false
```

## Common Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| 401 | Session expired | Re-login |
| 403 | Permission denied | Check account status |
| 429 | Rate limited | Back off and retry |
| 3000 | Duplicate WS connection | Close other connections |
