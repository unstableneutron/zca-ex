defmodule ZcaEx.Backfill.Adapter do
  @moduledoc """
  Adapter for fetching historical messages with timeout and correlation support.

  Provides a synchronous-style API over the asynchronous WebSocket old_messages mechanism.
  """

  alias ZcaEx.Events
  alias ZcaEx.Model.{Message, Reaction}
  alias ZcaEx.WS.Connection

  @default_timeout 10_000

  @type fetch_result ::
          {:ok, [Message.t()]} | {:error, :timeout | :not_ready | :not_found | term()}

  @doc """
  Fetch a page of old messages for the given thread type.

  Returns `{:ok, messages}` or `{:error, reason}`.

  Options:
  - `:timeout` - Max wait time in ms (default: 10_000)
  """
  @spec fetch_old_messages_page(String.t(), :user | :group, String.t() | nil, keyword()) ::
          fetch_result()
  def fetch_old_messages_page(account_id, thread_type, last_id \\ nil, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    topic = Events.Topic.build(account_id, :old_messages, thread_type)
    :ok = Events.subscribe(topic)

    try do
      flush_topic_events(topic)

      result =
        try do
          Connection.request_old_messages(account_id, thread_type, last_id)
        catch
          :exit, {:noproc, _} -> {:error, :not_found}
          :exit, {:timeout, _} -> {:error, :timeout}
          :exit, reason -> {:error, {:exit, reason}}
        end

      case result do
        {:ok, req_id} ->
          receive do
            {:zca_event, ^topic, %{req_id: ^req_id, messages: messages}} when is_list(messages) ->
              {:ok, messages}
          after
            timeout ->
              {:error, :timeout}
          end

        {:error, reason} ->
          {:error, reason}
      end
    after
      Events.unsubscribe(topic)
    end
  end

  @doc """
  Fetch old reactions for the given thread type.
  """
  @spec fetch_old_reactions_page(String.t(), :user | :group, String.t() | nil, keyword()) ::
          {:ok, [Reaction.t()]} | {:error, term()}
  def fetch_old_reactions_page(account_id, thread_type, last_id \\ nil, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    topic = Events.Topic.build(account_id, :old_reactions, thread_type)
    :ok = Events.subscribe(topic)

    try do
      flush_topic_events(topic)

      result =
        try do
          Connection.request_old_reactions(account_id, thread_type, last_id)
        catch
          :exit, {:noproc, _} -> {:error, :not_found}
          :exit, {:timeout, _} -> {:error, :timeout}
          :exit, reason -> {:error, {:exit, reason}}
        end

      case result do
        {:ok, req_id} ->
          receive do
            {:zca_event, ^topic, %{req_id: ^req_id, reactions: reactions}}
            when is_list(reactions) ->
              {:ok, reactions}
          after
            timeout ->
              {:error, :timeout}
          end

        {:error, reason} ->
          {:error, reason}
      end
    after
      Events.unsubscribe(topic)
    end
  end

  defp flush_topic_events(topic) do
    receive do
      {:zca_event, ^topic, _} -> flush_topic_events(topic)
    after
      0 -> :ok
    end
  end
end
