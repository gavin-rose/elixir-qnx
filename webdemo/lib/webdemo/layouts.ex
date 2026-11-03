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
          :root{
            --bg:#0a0a0b; --panel:#141416; --line:#2a2024; --txt:#e8e6e6;
            --mut:#86868c; --red:#e5342b; --red2:#ff5a4d;
          }
          *{box-sizing:border-box}
          body{margin:0;font:15px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;
            background:var(--bg);color:var(--txt);padding:44px 20px}
          .wrap{max-width:720px;margin:0 auto}
          h1{font-size:19px;letter-spacing:.16em;text-transform:uppercase;margin:0 0 4px;font-weight:700}
          h1 .arrow{color:var(--red);margin:0 6px}
          .sub{color:var(--mut);margin:0 0 26px;font-size:13px}
          .panel{border:1px solid var(--line);border-radius:12px;background:var(--panel);
            padding:20px 22px;margin-bottom:18px}
          .panel h2{font-size:11px;letter-spacing:.18em;text-transform:uppercase;
            color:var(--red);margin:0 0 16px;font-weight:700}
          .count{font-size:54px;font-weight:700;color:var(--red);line-height:1;margin:0}
          .count-label{color:var(--mut);font-size:12px;margin:4px 0 16px}
          button{font:inherit;font-size:13px;background:transparent;color:var(--txt);
            border:1px solid var(--red);border-radius:7px;padding:6px 13px;cursor:pointer;
            transition:background .12s,color .12s;margin:0 7px 7px 0}
          button:hover{background:var(--red);color:#fff}
          button.primary{background:var(--red);color:#fff}
          button.primary:hover{background:var(--red2)}
          table.kv{border-collapse:collapse;width:100%;font-size:13px;margin-top:4px}
          table.kv td{padding:5px 0;border-bottom:1px solid var(--line)}
          table.kv tr:last-child td{border-bottom:0}
          table.kv td:first-child{color:var(--mut)}
          table.kv td:last-child{color:var(--txt);text-align:right}
          .row{margin:0 0 10px}
          .row .lab{color:var(--mut);font-size:12px;margin-right:8px;display:inline-block;min-width:150px}
          .live{color:var(--red);font-size:12px;margin:12px 0 8px;display:flex;align-items:center}
          .live .dot{width:8px;height:8px;border-radius:50%;background:var(--red);
            margin-right:8px;animation:pulse 1s infinite}
          @keyframes pulse{0%,100%{opacity:1}50%{opacity:.25}}
          pre{background:#000;border:1px solid var(--line);border-radius:8px;padding:14px;
            overflow:auto;max-height:360px;color:#d7d7d7;font-size:12.5px;line-height:1.45;margin:0;white-space:pre-wrap}
          .statusrow{display:flex;align-items:center;margin-bottom:18px}
          .light{width:12px;height:12px;border-radius:50%;margin-right:10px;background:#555}
          .light.ok{background:#3ad16a;box-shadow:0 0 8px #3ad16a}
          .light.alarm{background:var(--red);box-shadow:0 0 8px var(--red);animation:pulse 1s infinite}
          .light.down{background:#999;animation:pulse .6s infinite}
          .statustext{text-transform:uppercase;letter-spacing:.14em;font-size:12px;color:var(--mut)}
          .readings{display:flex;gap:40px;margin-bottom:16px;flex-wrap:wrap}
          .reading .rv{font-size:34px;font-weight:700;color:var(--txt);line-height:1.1}
          .reading .rv .u{font-size:14px;color:var(--mut);margin-left:3px}
          .reading .rl{font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:var(--mut)}
          .spark{width:100%;height:120px;display:block;background:#000;border:1px solid var(--line);border-radius:8px}
        </style>
      </head>
      <body>
        <div class="wrap"><%= @inner_content %></div>
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
