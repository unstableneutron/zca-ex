defmodule ZcaEx.HTTP.AccountClientBehaviour do
  @moduledoc "Behaviour for HTTP client with account-specific cookie handling"

  @type headers :: [{String.t(), String.t()}]
  @type result :: {:ok, ZcaEx.HTTP.Response.t()} | {:error, term()}

  @callback get(term(), String.t(), String.t()) :: result()
  @callback get(term(), String.t(), String.t(), headers()) :: result()
  @callback post(term(), String.t(), binary(), String.t()) :: result()
  @callback post(term(), String.t(), binary(), String.t(), headers()) :: result()
  @callback post_form(term(), String.t(), map() | keyword(), String.t()) :: result()
  @callback post_form(term(), String.t(), map() | keyword(), String.t(), headers()) :: result()
  @callback post_multipart(term(), String.t(), [{String.t(), binary(), keyword()}], String.t()) ::
              result()
  @callback post_multipart(
              term(),
              String.t(),
              [{String.t(), binary(), keyword()}],
              String.t(),
              headers()
            ) :: result()
end
