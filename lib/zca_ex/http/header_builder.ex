defmodule ZcaEx.HTTP.HeaderBuilder do
  @moduledoc "Build default headers for Zalo API requests"

  @default_headers [
    {"accept", "application/json, text/plain, */*"},
    {"accept-encoding", "gzip, deflate"},
    {"accept-language", "en-US,en;q=0.9"},
    {"cache-control", "no-cache"},
    {"origin", "https://chat.zalo.me"},
    {"referer", "https://chat.zalo.me/"},
    {"sec-ch-ua", "\"Chromium\";v=\"128\", \"Not;A=Brand\";v=\"24\""},
    {"sec-ch-ua-mobile", "?0"},
    {"sec-ch-ua-platform", "\"macOS\""},
    {"sec-fetch-dest", "empty"},
    {"sec-fetch-mode", "cors"},
    {"sec-fetch-site", "same-site"}
  ]

  @spec build(String.t()) :: [{String.t(), String.t()}]
  def build(user_agent) do
    [{"user-agent", user_agent} | @default_headers]
  end

  @spec with_cookie(list(), String.t()) :: [{String.t(), String.t()}]
  def with_cookie(headers, cookie_string) do
    [{"cookie", cookie_string} | headers]
  end
end
