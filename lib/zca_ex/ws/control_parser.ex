defmodule ZcaEx.WS.ControlParser do
  @moduledoc "Parses cmd=601 control events into specific event types"

  @doc """
  Parse control event payload into specific events.

  Returns a list of {event_type, payload} tuples to dispatch.

  ## Control Types

  - `file_done` -> `:upload_attachment` with file URL and ID
  - `group` -> `:group_event` with parsed group event data
  - `fr` (friend) -> `:friend_event` with parsed friend event data

  ## Examples

      iex> payload = %{"data" => %{"controls" => [%{"content" => %{"act_type" => "file_done", "fileId" => "123", "data" => %{"url" => "https://..."}}}]}}
      iex> ZcaEx.WS.ControlParser.parse(payload)
      [{:upload_attachment, %{file_id: "123", file_url: "https://..."}}]

  """
  @spec parse(map()) :: [{atom(), map()}]
  def parse(%{"data" => %{"controls" => controls}}) when is_list(controls) do
    controls
    |> Enum.flat_map(&parse_control/1)
  end

  def parse(_payload), do: []

  defp parse_control(%{"content" => content}) do
    case content do
      %{"act_type" => "file_done"} ->
        parse_file_done(content)

      %{"act_type" => "group", "act" => act} ->
        parse_group_event(content, act)

      %{"act_type" => "fr", "act" => act} ->
        parse_friend_event(content, act)

      _ ->
        []
    end
  end

  defp parse_control(_), do: []

  defp parse_file_done(%{"fileId" => file_id, "data" => %{"url" => url}}) do
    [{:upload_attachment, %{file_id: to_string(file_id), file_url: url}}]
  end

  defp parse_file_done(_), do: []

  # Zalo sends both join and join_reject when admin approves join requests
  # Ignore join_reject as Zalo itself doesn't handle this properly
  defp parse_group_event(%{"act" => "join_reject"}, _act), do: []

  defp parse_group_event(%{"data" => data, "act" => act}, _act) do
    parsed_data = maybe_parse_json(data)
    [{:group_event, %{data: parsed_data, act: act}}]
  end

  defp parse_group_event(_, _), do: []

  # Zalo sends both req and req_v2 when user sends friend request
  # Ignore req as Zalo itself doesn't handle this properly
  defp parse_friend_event(%{"act" => "req"}, _act), do: []

  defp parse_friend_event(%{"data" => data, "act" => act}, _act) do
    parsed_data =
      data
      |> maybe_parse_json()
      |> maybe_parse_topic_params()

    [{:friend_event, %{data: parsed_data, act: act}}]
  end

  defp parse_friend_event(_, _), do: []

  defp maybe_parse_json(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> decoded
      {:error, _} -> data
    end
  end

  defp maybe_parse_json(data), do: data

  # Handle case when act is "pin_create" and topic.params is a string
  defp maybe_parse_topic_params(%{"topic" => %{"params" => params} = topic} = data)
       when is_binary(params) do
    case Jason.decode(params) do
      {:ok, decoded_params} ->
        %{data | "topic" => %{topic | "params" => decoded_params}}

      {:error, _} ->
        data
    end
  end

  defp maybe_parse_topic_params(data), do: data
end
