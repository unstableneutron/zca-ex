defmodule ZcaEx.Api.LoginQR.Events do
  @moduledoc "Event types for QR login flow"

  @type qr_options :: %{
          enabled_check_ocr: boolean(),
          enabled_multi_layer: boolean()
        }

  @type qr_generated :: %{
          type: :qr_generated,
          code: String.t(),
          image: String.t(),
          options: qr_options()
        }

  @type qr_expired :: %{
          type: :qr_expired
        }

  @type qr_scanned :: %{
          type: :qr_scanned,
          avatar: String.t(),
          display_name: String.t()
        }

  @type qr_declined :: %{
          type: :qr_declined,
          code: String.t()
        }

  @type login_complete :: %{
          type: :login_complete,
          cookies: [map()],
          imei: String.t(),
          user_agent: String.t(),
          user_info: %{name: String.t(), avatar: String.t()}
        }

  @type login_error :: %{
          type: :login_error,
          error: ZcaEx.Error.t()
        }

  @type t :: qr_generated() | qr_expired() | qr_scanned() | qr_declined() | login_complete() | login_error()

  @spec qr_generated(String.t(), String.t(), qr_options()) :: qr_generated()
  def qr_generated(code, image, options) do
    %{
      type: :qr_generated,
      code: code,
      image: image,
      options: options
    }
  end

  @spec qr_expired() :: qr_expired()
  def qr_expired do
    %{type: :qr_expired}
  end

  @spec qr_scanned(String.t(), String.t()) :: qr_scanned()
  def qr_scanned(avatar, display_name) do
    %{
      type: :qr_scanned,
      avatar: avatar,
      display_name: display_name
    }
  end

  @spec qr_declined(String.t()) :: qr_declined()
  def qr_declined(code) do
    %{
      type: :qr_declined,
      code: code
    }
  end

  @spec login_complete([map()], String.t(), String.t(), map()) :: login_complete()
  def login_complete(cookies, imei, user_agent, user_info) do
    %{
      type: :login_complete,
      cookies: cookies,
      imei: imei,
      user_agent: user_agent,
      user_info: user_info
    }
  end

  @spec login_error(ZcaEx.Error.t()) :: login_error()
  def login_error(error) do
    %{
      type: :login_error,
      error: error
    }
  end
end
