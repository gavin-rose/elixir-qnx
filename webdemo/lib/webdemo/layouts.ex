defmodule Webdemo.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>Elixir on QNX</title>
        <style>
          body{font:16px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;background:#0f1115;color:#d6dae0;margin:0;padding:48px}
          h1{font-size:22px;letter-spacing:.03em}
          .card{max-width:680px;border:1px solid #262b33;border-radius:10px;padding:20px 24px;background:#161a21}
          .k{color:#8a91a0}.v{color:#fbbf24}
          button{font:inherit;background:#3b82f6;color:#fff;border:0;border-radius:6px;padding:6px 14px;cursor:pointer}
          .big{font-size:44px;color:#fbbf24;margin:6px 0}
          table{border-collapse:collapse;margin-top:14px}td{padding:2px 12px 2px 0}
        </style>
      </head>
      <body>
        <%= @inner_content %>
        <script src="/js/phoenix/phoenix.min.js"></script>
        <script src="/js/lv/phoenix_live_view.min.js"></script>
        <script>
          const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
          const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {params: {_csrf_token: csrfToken}});
          liveSocket.connect();
        </script>
      </body>
    </html>
    """
  end
end
