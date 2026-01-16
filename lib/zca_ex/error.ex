defmodule ZcaEx.Error do
  @moduledoc "Error struct for Zalo API errors"

  @type category :: :network | :api | :crypto | :auth | :websocket | :unknown

  @type t :: %__MODULE__{
          category: category(),
          code: integer() | nil,
          message: String.t(),
          reason: term(),
          retryable?: boolean(),
          details: map()
        }

  defexception [:category, :code, :message, :reason, :retryable?, :details]

  @impl true
  @spec message(t()) :: String.t()
  def message(%{category: category, message: msg, code: nil}) do
    "[#{category}] #{msg}"
  end

  def message(%{category: category, message: msg, code: code}) do
    "[#{category}:#{code}] #{msg}"
  end

  @spec new(category(), String.t(), keyword()) :: t()
  def new(category, message, opts \\ []) do
    %__MODULE__{
      category: category,
      code: Keyword.get(opts, :code),
      message: message,
      reason: Keyword.get(opts, :reason),
      retryable?: Keyword.get(opts, :retryable?, false),
      details: Keyword.get(opts, :details, %{})
    }
  end

  @spec network(String.t(), keyword()) :: t()
  def network(message, opts \\ []) do
    opts = Keyword.put_new(opts, :retryable?, true)
    new(:network, message, opts)
  end

  @spec api(integer() | nil, String.t(), keyword()) :: t()
  def api(code, message, opts \\ []) do
    opts = Keyword.put(opts, :code, code)
    new(:api, message, opts)
  end

  @spec crypto(String.t(), keyword()) :: t()
  def crypto(message, opts \\ []) do
    new(:crypto, message, opts)
  end

  @spec auth(String.t(), keyword()) :: t()
  def auth(message, opts \\ []) do
    new(:auth, message, opts)
  end

  @spec websocket(String.t(), keyword()) :: t()
  def websocket(message, opts \\ []) do
    opts = Keyword.put_new(opts, :retryable?, true)
    new(:websocket, message, opts)
  end

  @spec normalize(term()) :: t()
  def normalize(%__MODULE__{} = error), do: error

  def normalize(%{__struct__: Mint.TransportError, reason: reason}) do
    network("Transport error: #{inspect(reason)}", reason: reason)
  end

  def normalize(%{__struct__: Mint.HTTPError, reason: reason}) do
    network("HTTP error: #{inspect(reason)}", reason: reason)
  end

  def normalize({:error, :timeout}) do
    network("Connection timeout", reason: :timeout)
  end

  def normalize({:error, :closed}) do
    network("Connection closed", reason: :closed)
  end

  def normalize({:error, reason}) when is_atom(reason) do
    new(:unknown, Atom.to_string(reason), reason: reason)
  end

  def normalize(%{__struct__: Jason.DecodeError} = error) do
    crypto("JSON decode error: #{Exception.message(error)}", reason: error)
  end

  def normalize(%{__struct__: _} = exception) do
    message =
      if is_exception(exception) do
        Exception.message(exception)
      else
        inspect(exception)
      end

    new(:unknown, message, reason: exception)
  end

  def normalize(other) do
    new(:unknown, inspect(other), reason: other)
  end

  @spec retryable?(t() | term()) :: boolean()
  def retryable?(%__MODULE__{retryable?: retryable?}), do: retryable?
  def retryable?(_), do: false
end
