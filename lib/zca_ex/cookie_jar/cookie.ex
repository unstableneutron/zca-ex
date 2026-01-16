defmodule ZcaEx.CookieJar.Cookie do
  @moduledoc "Cookie struct representing an HTTP cookie"

  @type same_site :: :strict | :lax | :none | nil

  @type t :: %__MODULE__{
          name: String.t(),
          value: String.t(),
          domain: String.t(),
          path: String.t(),
          secure: boolean(),
          http_only: boolean(),
          host_only: boolean(),
          expires_at: integer() | nil,
          creation_time: integer(),
          same_site: same_site(),
          max_age: integer() | nil
        }

  defstruct [
    :name,
    :value,
    :domain,
    path: "/",
    secure: false,
    http_only: false,
    host_only: false,
    expires_at: nil,
    creation_time: nil,
    same_site: nil,
    max_age: nil
  ]
end
