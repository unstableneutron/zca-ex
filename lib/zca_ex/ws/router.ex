defmodule ZcaEx.WS.Router do
  @moduledoc "Routes WebSocket events by cmd/subCmd to event types"

  @type event_type ::
          :cipher_key
          | :ping
          | :message
          | :control
          | :reaction
          | :old_reactions
          | :old_messages
          | :typing
          | :seen_delivered
          | :duplicate
          | :unknown

  @type thread_type :: :user | :group

  @doc """
  Route a frame header to event type and thread type.

  ## Examples

      iex> ZcaEx.WS.Router.route({1, 1, 1})
      {:cipher_key, nil}

      iex> ZcaEx.WS.Router.route({1, 501, 0})
      {:message, :user}

      iex> ZcaEx.WS.Router.route({1, 521, 0})
      {:message, :group}

      iex> ZcaEx.WS.Router.route({1, 510, 1})
      {:old_messages, :user}

      iex> ZcaEx.WS.Router.route({1, 3000, 0})
      {:duplicate, nil}
  """
  @spec route({version :: integer(), cmd :: integer(), sub_cmd :: integer()}) ::
          {event_type(), thread_type() | nil}

  # Handshake - cipher key exchange
  def route({_version, 1, 1}), do: {:cipher_key, nil}

  # Heartbeat/ping response
  def route({_version, 2, 1}), do: {:ping, nil}

  # User message / undo
  def route({_version, 501, 0}), do: {:message, :user}

  # Group message / undo
  def route({_version, 521, 0}), do: {:message, :group}

  # Control events (file upload, group/friend events)
  def route({_version, 601, 0}), do: {:control, nil}

  # Real-time reactions (both user and group in same event)
  def route({_version, 612, _sub_cmd}), do: {:reaction, nil}

  # User reactions history
  def route({_version, 610, 1}), do: {:old_reactions, :user}

  # Group reactions history
  def route({_version, 611, 1}), do: {:old_reactions, :group}

  # User messages history
  def route({_version, 510, 1}), do: {:old_messages, :user}

  # Group messages history
  def route({_version, 511, 1}), do: {:old_messages, :group}

  # Typing indicators
  def route({_version, 602, 0}), do: {:typing, nil}

  # User read receipts (seen/delivered)
  def route({_version, 502, 0}), do: {:seen_delivered, :user}

  # Group read receipts (seen/delivered)
  def route({_version, 522, 0}), do: {:seen_delivered, :group}

  # Duplicate connection
  def route({_version, 3000, 0}), do: {:duplicate, nil}

  # Unknown command
  def route({_version, _cmd, _sub_cmd}), do: {:unknown, nil}

  @decrypted_events MapSet.new([
    :message,
    :reaction,
    :old_reactions,
    :old_messages,
    :typing,
    :seen_delivered
  ])

  @doc """
  Check if this event type requires AES-GCM decryption.

  Events that need decryption are those that call decodeEventData in the JS implementation:
  :message, :reaction, :old_reactions, :old_messages, :typing, :seen_delivered

  ## Examples

      iex> ZcaEx.WS.Router.needs_decryption?(:message)
      true

      iex> ZcaEx.WS.Router.needs_decryption?(:cipher_key)
      false
  """
  @spec needs_decryption?(event_type()) :: boolean()
  def needs_decryption?(event_type) do
    MapSet.member?(@decrypted_events, event_type)
  end

  @doc """
  Check if data needs decompression based on encrypt type.

  - encrypt type 0: no encryption, no compression
  - encrypt type 1: encrypted + compressed (zlib inflate)
  - encrypt type 2: encrypted + compressed (URL-encoded first)
  - encrypt type 3: encrypted, no compression

  ## Examples

      iex> ZcaEx.WS.Router.needs_decompression?(0)
      false

      iex> ZcaEx.WS.Router.needs_decompression?(1)
      true

      iex> ZcaEx.WS.Router.needs_decompression?(2)
      true

      iex> ZcaEx.WS.Router.needs_decompression?(3)
      false
  """
  @spec needs_decompression?(0 | 1 | 2 | 3) :: boolean()
  def needs_decompression?(encrypt_type) when encrypt_type in [1, 2], do: true
  def needs_decompression?(_encrypt_type), do: false
end
