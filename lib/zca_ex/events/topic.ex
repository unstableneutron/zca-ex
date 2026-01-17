defmodule ZcaEx.Events.Topic do
  @moduledoc ~S"""
  Topic building helpers for ZcaEx events.

  Topic naming convention:
  - `zca:<account_id>:<event_type>`
  - `zca:<account_id>:<event_type>:<sub_type>`
  """

  @event_types [
    :connected,
    :disconnected,
    :closed,
    :error,
    :ready,
    :message,
    :old_messages,
    :reaction,
    :old_reactions,
    :typing,
    :seen,
    :delivered,
    :friend_event,
    :group_event,
    :upload_attachment,
    :undo,
    :cipher_key
  ]

  @doc """
  Returns the list of supported event types.
  """
  @spec event_types() :: [atom()]
  def event_types, do: @event_types

  @doc """
  Builds a topic string for the given account, event type, and optional sub-type.

  ## Examples

      iex> ZcaEx.Events.Topic.build("acc123", :message)
      "zca:acc123:message"

      iex> ZcaEx.Events.Topic.build("acc123", :message, :group)
      "zca:acc123:message:group"

  """
  @spec build(account_id :: String.t() | atom(), event_type :: atom(), sub_type :: atom() | nil) ::
          String.t()
  def build(account_id, event_type, sub_type \\ nil)

  def build(account_id, event_type, sub_type) when is_atom(account_id) do
    build(Atom.to_string(account_id), event_type, sub_type)
  end

  def build(account_id, event_type, nil) when is_binary(account_id) and is_atom(event_type) do
    "zca:#{account_id}:#{event_type}"
  end

  def build(account_id, event_type, sub_type)
      when is_binary(account_id) and is_atom(event_type) and is_atom(sub_type) do
    "zca:#{account_id}:#{event_type}:#{sub_type}"
  end

  @doc """
  Parses a topic string back into its components.

  ## Examples

      iex> ZcaEx.Events.Topic.parse("zca:acc123:message")
      {:ok, %{account_id: "acc123", event_type: :message, sub_type: nil}}

      iex> ZcaEx.Events.Topic.parse("zca:acc123:message:group")
      {:ok, %{account_id: "acc123", event_type: :message, sub_type: :group}}

  """
  @spec parse(String.t()) ::
          {:ok, %{account_id: String.t(), event_type: atom(), sub_type: atom() | nil}}
          | {:error, :invalid_topic}
  def parse("zca:" <> rest) do
    case String.split(rest, ":", parts: 3) do
      [account_id, event_type] ->
        {:ok,
         %{
           account_id: account_id,
           event_type: String.to_existing_atom(event_type),
           sub_type: nil
         }}

      [account_id, event_type, sub_type] ->
        {:ok,
         %{
           account_id: account_id,
           event_type: String.to_existing_atom(event_type),
           sub_type: String.to_existing_atom(sub_type)
         }}

      _ ->
        {:error, :invalid_topic}
    end
  rescue
    ArgumentError -> {:error, :invalid_topic}
  end

  def parse(_), do: {:error, :invalid_topic}
end
