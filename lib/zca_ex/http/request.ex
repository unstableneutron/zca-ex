defmodule ZcaEx.HTTP.Request do
  @moduledoc "HTTP request struct"

  @type t :: %__MODULE__{
          method: :get | :post,
          url: String.t(),
          headers: [{String.t(), String.t()}],
          body: binary() | nil
        }

  defstruct [
    method: :get,
    url: "",
    headers: [],
    body: nil
  ]
end
