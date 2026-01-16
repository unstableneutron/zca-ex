defmodule ZcaEx.CookieJar.Parser do
  @moduledoc "Parser for Set-Cookie headers"

  alias ZcaEx.CookieJar.Cookie

  @doc """
  Parse a Set-Cookie header into a Cookie struct.
  Returns {:ok, cookie} or {:error, reason}.
  """
  @spec parse(String.t(), URI.t()) :: {:ok, Cookie.t()} | {:error, term()}
  def parse(header, uri) when is_binary(header) do
    case String.split(header, ";") do
      [name_value | attributes] ->
        case parse_name_value(name_value) do
          {:ok, name, value} ->
            attrs = parse_attributes(attributes)
            build_cookie(name, value, attrs, uri)

          :error ->
            {:error, :invalid_cookie}
        end

      [] ->
        {:error, :empty_cookie}
    end
  end

  defp parse_name_value(str) do
    case String.split(String.trim(str), "=", parts: 2) do
      [name, value] when name != "" ->
        {:ok, String.trim(name), String.trim(value)}

      _ ->
        :error
    end
  end

  defp parse_attributes(attrs) do
    Enum.reduce(attrs, %{}, fn attr, acc ->
      attr = String.trim(attr)

      case String.downcase(attr) do
        "secure" ->
          Map.put(acc, :secure, true)

        "httponly" ->
          Map.put(acc, :http_only, true)

        _ ->
          case String.split(attr, "=", parts: 2) do
            [key, value] ->
              parse_attribute(String.downcase(String.trim(key)), String.trim(value), acc)

            _ ->
              acc
          end
      end
    end)
  end

  defp parse_attribute("domain", value, acc) do
    domain = value |> String.trim_leading(".") |> String.downcase()
    Map.put(acc, :domain, domain)
  end

  defp parse_attribute("path", value, acc) do
    Map.put(acc, :path, value)
  end

  defp parse_attribute("expires", value, acc) do
    case parse_expires(value) do
      {:ok, timestamp} ->
        Map.put_new(acc, :expires_at, timestamp)

      :error ->
        acc
    end
  end

  defp parse_attribute("max-age", value, acc) do
    case Integer.parse(value) do
      {seconds, ""} ->
        expires_at = System.system_time(:second) + seconds
        Map.put(acc, :expires_at, expires_at)

      _ ->
        acc
    end
  end

  defp parse_attribute(_key, _value, acc), do: acc

  defp parse_expires(date_string) do
    regexes = [
      ~r/^\w+,\s+(\d{1,2})\s+(\w+)\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$/i,
      ~r/^\w+,\s+(\d{1,2})-(\w+)-(\d{2,4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$/i
    ]

    Enum.find_value(regexes, :error, fn regex ->
      case Regex.run(regex, date_string) do
        [_, day, month, year, hour, min, sec] ->
          with {:ok, month_num} <- parse_month(month),
               {day_int, ""} <- Integer.parse(day),
               {year_int, ""} <- Integer.parse(year),
               {hour_int, ""} <- Integer.parse(hour),
               {min_int, ""} <- Integer.parse(min),
               {sec_int, ""} <- Integer.parse(sec) do
            year_int = if year_int < 100, do: 2000 + year_int, else: year_int

            case NaiveDateTime.new(year_int, month_num, day_int, hour_int, min_int, sec_int) do
              {:ok, ndt} ->
                {:ok, DateTime.to_unix(DateTime.from_naive!(ndt, "Etc/UTC"))}

              _ ->
                nil
            end
          else
            _ -> nil
          end

        _ ->
          nil
      end
    end)
  rescue
    _ -> :error
  end

  @months %{
    "jan" => 1,
    "feb" => 2,
    "mar" => 3,
    "apr" => 4,
    "may" => 5,
    "jun" => 6,
    "jul" => 7,
    "aug" => 8,
    "sep" => 9,
    "oct" => 10,
    "nov" => 11,
    "dec" => 12
  }

  defp parse_month(month) do
    case Map.get(@months, String.downcase(String.slice(month, 0, 3))) do
      nil -> :error
      num -> {:ok, num}
    end
  end

  defp build_cookie(name, value, attrs, uri) do
    now = System.system_time(:second)
    request_host = String.downcase(uri.host || "")

    {domain, host_only} =
      case Map.get(attrs, :domain) do
        nil ->
          {request_host, true}

        domain ->
          if domain_matches?(request_host, domain) do
            {domain, false}
          else
            {request_host, true}
          end
      end

    path =
      case Map.get(attrs, :path) do
        nil -> default_path(uri.path)
        path -> path
      end

    cookie = %Cookie{
      name: name,
      value: value,
      domain: domain,
      path: path,
      secure: Map.get(attrs, :secure, false),
      http_only: Map.get(attrs, :http_only, false),
      host_only: host_only,
      expires_at: Map.get(attrs, :expires_at),
      creation_time: now
    }

    {:ok, cookie}
  end

  defp domain_matches?(request_host, cookie_domain) do
    request_host == cookie_domain or
      String.ends_with?(request_host, "." <> cookie_domain)
  end

  defp default_path(nil), do: "/"
  defp default_path(""), do: "/"

  defp default_path(path) do
    case String.split(path, "/") |> Enum.drop(-1) |> Enum.join("/") do
      "" -> "/"
      p -> p
    end
  end
end
