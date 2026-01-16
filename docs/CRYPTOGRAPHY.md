# Cryptography

ZcaEx implements Zalo's request signing and encryption using Erlang's `:crypto` module.

## Two AES-CBC Key Types

ZcaEx uses AES-CBC in two distinct contexts with different keys:

| Context | Key Source | Key Format | Used For |
|---------|------------|------------|----------|
| Login | `ParamsEncryptor.encrypt_key` | UTF-8 string | `getLoginInfo`, `getServerInfo` |
| API calls | `Session.secret_key` | Base64-encoded | All other endpoints |

> **Important:** Don't confuse `encrypt_key` (login only) with `secret_key` (API calls). Using the wrong key causes decryption failures.

## Login Encryption (ParamsEncryptor)

Used only during login to encrypt `getLoginInfo` and `getServerInfo` requests.

```
ParamsEncryptor.derive_keys()
    │
    ├─► zcid_ext (random string)
    │
    ├─► zcid = MD5(zcid_ext)
    │
    └─► encrypt_key = shuffle(MD5(zcid_ext), zcid)
            │
            ▼
        AesCbc.encrypt_utf8_key(params, encrypt_key)
```

## API Encryption (Session Secret Key)

Used for all regular API endpoints after login.

```
session.secret_key (Base64)
    │
    ▼
AesCbc.encrypt_base64_key(params, secret_key)
    │
    ▼
HTTP POST
    │
    ▼
AesCbc.decrypt_base64_key(response, secret_key)
```

## Request Signing (SignKey)

All requests include an MD5 signature for authentication:

```
signkey = MD5("zsecure" + type + sorted_param_values)
```

Parameters are sorted alphabetically by key, then their values are concatenated.

## AES-GCM (WebSocket)

Used for decrypting real-time WebSocket event payloads.

Buffer format:
```
┌─────────┬─────────┬────────────┬─────────┐
│ IV 16B  │ AAD 16B │ Ciphertext │ Tag 16B │
└─────────┴─────────┴────────────┴─────────┘
```

The `cipher_key` for decryption arrives as a WebSocket frame (cmd=1, subCmd=1) after connection.

```elixir
ZcaEx.Crypto.AesGcm.decrypt(buffer, cipher_key)
```

## Encryption Algorithms Summary

| Algorithm | Module | Key Type | Used For |
|-----------|--------|----------|----------|
| AES-256-CBC | `Crypto.AesCbc` | UTF-8 or Base64 | HTTP request/response bodies |
| AES-256-GCM | `Crypto.AesGcm` | Binary | WebSocket event payloads |
| MD5 | `Crypto.SignKey` | — | Request signatures |

## API Request Flow

```
Build params map
    │
    ▼
encrypt_params(params, session.secret_key)
    │   Uses AES-CBC with Base64 key
    │
    ▼
SignKey.sign(type, outer_params)
    │
    ▼
HTTP POST via AccountClient
    │
    ▼
Api.Response.parse(body, session.secret_key)
    │   Decrypts with same Base64 key
    │
    ▼
Decoded JSON result
```
