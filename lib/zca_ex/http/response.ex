defmodule ZcaEx.HTTP.Response do
  @moduledoc "HTTP response struct"

  @type t :: %__MODULE__{
          status: integer(),
          headers: [{String.t(), String.t()}],
          body: binary()
        }

  defstruct [:status, :headers, :body]
end
