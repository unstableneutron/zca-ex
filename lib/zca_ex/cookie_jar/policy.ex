defmodule ZcaEx.CookieJar.Policy do
  @moduledoc """
  RFC6265 cookie policy module for domain/path matching rules.
  """

  alias ZcaEx.CookieJar.Cookie

  @allowed_domains ["zalo.me", "zaloapp.com", "chat.zalo.me"]

  @doc """
  RFC6265 domain matching.
  If cookie.host_only is true, exact match required.
  Otherwise, cookie domain must be a suffix of request host.
  """
  @spec domain_matches?(String.t(), Cookie.t()) :: boolean()
  def domain_matches?(request_host, %Cookie{host_only: true, domain: domain}) do
    normalize_domain(request_host) == normalize_domain(domain)
  end

  def domain_matches?(request_host, %Cookie{domain: domain}) do
    request_host = normalize_domain(request_host)
    domain = normalize_domain(domain)

    request_host == domain or String.ends_with?(request_host, "." <> domain)
  end

  @doc """
  RFC6265 path matching.
  Cookie path equals request path, OR
  Cookie path is a prefix of request path AND (cookie path ends with / OR char after prefix is /)
  """
  @spec path_matches?(String.t(), String.t()) :: boolean()
  def path_matches?(request_path, cookie_path) do
    request_path = request_path || "/"
    cookie_path = cookie_path || "/"

    request_path == cookie_path or
      (String.starts_with?(request_path, cookie_path) and
         (String.ends_with?(cookie_path, "/") or
            String.at(request_path, String.length(cookie_path)) == "/"))
  end

  @doc """
  Calculate default cookie path from request URI per RFC6265.
  - If path is empty or doesn't start with /, return "/"
  - If path has only one /, return "/"
  - Otherwise return path up to (but not including) the rightmost /
  """
  @spec default_path(String.t() | nil) :: String.t()
  def default_path(nil), do: "/"
  def default_path(""), do: "/"

  def default_path(path) do
    if not String.starts_with?(path, "/") do
      "/"
    else
      case String.split(path, "/") |> Enum.drop(-1) |> Enum.join("/") do
        "" -> "/"
        "/" -> "/"
        p -> p
      end
    end
  end

  @doc """
  Check if domain is a public suffix.
  Returns false for Zalo domains (allowed).
  Returns true for TLD-only domains or apparent public suffixes.
  """
  @spec public_suffix?(String.t()) :: boolean()
  def public_suffix?(domain) do
    domain = normalize_domain(domain)

    cond do
      domain in @allowed_domains -> false
      Enum.any?(@allowed_domains, &String.ends_with?(domain, "." <> &1)) -> false
      not String.contains?(domain, ".") -> true
      tld_only?(domain) -> true
      true -> false
    end
  end

  @doc """
  Normalize domain for storage: lowercase and remove leading dot.
  """
  @spec normalize_domain(String.t()) :: String.t()
  def normalize_domain(domain) when is_binary(domain) do
    domain
    |> String.downcase()
    |> String.trim_leading(".")
  end

  def normalize_domain(nil), do: ""

  @doc """
  Validate that cookie domain is valid for the request host.
  Domain must match or be a parent domain of request host.
  """
  @spec valid_domain_for_request?(String.t(), String.t()) :: boolean()
  def valid_domain_for_request?(request_host, cookie_domain) do
    request_host = normalize_domain(request_host)
    cookie_domain = normalize_domain(cookie_domain)

    cond do
      public_suffix?(cookie_domain) and cookie_domain not in @allowed_domains -> false
      request_host == cookie_domain -> true
      String.ends_with?(request_host, "." <> cookie_domain) -> true
      true -> false
    end
  end

  defp tld_only?(domain) do
    parts = String.split(domain, ".")

    case length(parts) do
      1 -> true
      2 -> second_level_tld?(Enum.at(parts, 1))
      _ -> false
    end
  end

  @known_second_level_tlds [
    "co.uk",
    "com.au",
    "co.nz",
    "co.jp",
    "com.br",
    "com.vn",
    "edu.vn",
    "gov.vn"
  ]

  defp second_level_tld?(tld) do
    Enum.any?(@known_second_level_tlds, &String.ends_with?(&1, tld))
  end
end
