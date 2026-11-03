defmodule Webdemo.Router do
  @moduledoc false
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    conn |> put_resp_content_type("text/html") |> send_resp(200, page())
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp page do
    arch = List.to_string(:erlang.system_info(:system_architecture))
    {fam, name} = :os.type()
    otp = List.to_string(:erlang.system_info(:otp_release))

    """
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Elixir on QNX</title>
    <style>
      body{font:16px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;background:#0f1115;color:#d6dae0;margin:0;padding:48px}
      h1{font-size:22px;letter-spacing:.04em}
      .card{max-width:660px;border:1px solid #262b33;border-radius:10px;padding:20px 24px;background:#161a21}
      .k{color:#8a91a0}.v{color:#fbbf24}
      table{border-collapse:collapse}td{padding:3px 12px 3px 0;vertical-align:top}
    </style></head>
    <body>
      <h1>Phoenix stack on QNX</h1>
      <div class="card">
        <p>Served by <b>Bandit</b> on the <b>BEAM</b>, running on the
        <b>QNX 8.0</b> real-time OS in QEMU, viewed from your browser.</p>
        <table>
          <tr><td class="k">system_architecture</td><td class="v">#{arch}</td></tr>
          <tr><td class="k">os:type</td><td class="v">{#{fam}, #{name}}</td></tr>
          <tr><td class="k">otp_release</td><td class="v">#{otp}</td></tr>
          <tr><td class="k">elixir</td><td class="v">#{System.version()}</td></tr>
          <tr><td class="k">schedulers_online</td><td class="v">#{System.schedulers_online()}</td></tr>
          <tr><td class="k">utc_now</td><td class="v">#{DateTime.utc_now()}</td></tr>
        </table>
      </div>
    </body></html>
    """
  end
end
