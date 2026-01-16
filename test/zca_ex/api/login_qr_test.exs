defmodule ZcaEx.Api.LoginQRTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.LoginQR
  alias ZcaEx.Api.LoginQR.Events

  describe "extract_version/1" do
    test "extracts version from HTML with version in script src" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <script src="https://stc-zlogin.zdn.vn/main-2.40.9.js"></script>
      </head>
      <body>Login</body>
      </html>
      """

      assert {:ok, "2.40.9"} = LoginQR.extract_version(html)
    end

    test "extracts version with different version format" do
      html = """
      <script src="https://stc-zlogin.zdn.vn/main-1.0.0.js"></script>
      """

      assert {:ok, "1.0.0"} = LoginQR.extract_version(html)
    end

    test "extracts version from complex HTML" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Zalo Login</title>
        <link rel="stylesheet" href="/styles.css">
        <script src="https://some-other-domain.com/app.js"></script>
        <script src="https://stc-zlogin.zdn.vn/main-3.14.159.js"></script>
        <script src="https://analytics.example.com/track.js"></script>
      </head>
      <body></body>
      </html>
      """

      assert {:ok, "3.14.159"} = LoginQR.extract_version(html)
    end

    test "returns error when no version found" do
      html = """
      <!DOCTYPE html>
      <html>
      <head><title>No Script</title></head>
      <body>Hello</body>
      </html>
      """

      assert :error = LoginQR.extract_version(html)
    end

    test "returns error for empty HTML" do
      assert :error = LoginQR.extract_version("")
    end

    test "returns error for HTML without matching script" do
      html = """
      <script src="https://other-domain.com/main-1.0.0.js"></script>
      """

      assert :error = LoginQR.extract_version(html)
    end
  end

  describe "Events" do
    test "creates qr_generated event" do
      options = %{enabled_check_ocr: true, enabled_multi_layer: false}
      event = Events.qr_generated("abc123", "base64data", options)

      assert event == %{
               type: :qr_generated,
               code: "abc123",
               image: "base64data",
               options: options
             }
    end

    test "creates qr_expired event" do
      event = Events.qr_expired()
      assert event == %{type: :qr_expired}
    end

    test "creates qr_scanned event" do
      event = Events.qr_scanned("https://avatar.url", "John Doe")

      assert event == %{
               type: :qr_scanned,
               avatar: "https://avatar.url",
               display_name: "John Doe"
             }
    end

    test "creates qr_declined event" do
      event = Events.qr_declined("code123")

      assert event == %{
               type: :qr_declined,
               code: "code123"
             }
    end

    test "creates login_complete event" do
      cookies = [%{"name" => "session", "value" => "abc"}]
      user_info = %{name: "Test User", avatar: "https://avatar.url"}
      event = Events.login_complete(cookies, "imei123", "Mozilla/5.0", user_info)

      assert event == %{
               type: :login_complete,
               cookies: cookies,
               imei: "imei123",
               user_agent: "Mozilla/5.0",
               user_info: user_info
             }
    end

    test "creates login_error event" do
      error = ZcaEx.Error.api(100, "Test error")
      event = Events.login_error(error)

      assert event == %{
               type: :login_error,
               error: error
             }
    end
  end

  describe "state machine" do
    test "starts in initializing state" do
      {:ok, pid} = LoginQR.start(self(), user_agent: "Test/1.0")

      assert Process.alive?(pid)
      LoginQR.abort(pid)
    end

    test "abort stops the process" do
      {:ok, pid} = LoginQR.start(self(), user_agent: "Test/1.0")

      ref = Process.monitor(pid)
      LoginQR.abort(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
    end

    test "retry restarts the flow" do
      {:ok, pid} = LoginQR.start(self(), user_agent: "Test/1.0")

      LoginQR.retry(pid)
      assert Process.alive?(pid)

      LoginQR.abort(pid)
    end
  end

  describe "event sending" do
    @tag :external
    test "sends qr_generated event on successful flow start" do
      {:ok, pid} = LoginQR.start(self(), user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36")

      assert_receive {:zca_qr_login, %{type: :qr_generated, code: code, image: image}}, 10_000
      assert is_binary(code)
      assert is_binary(image)
      assert byte_size(image) > 100

      LoginQR.abort(pid)
    end
  end
end
