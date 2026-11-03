defmodule Webdemo.Endpoint do
  use Phoenix.Endpoint, otp_app: :webdemo

  @session_options [
    store: :cookie,
    key: "_webdemo_key",
    signing_salt: "qnxsalt0",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  # Serve the prebuilt client JS straight from the deps (no asset pipeline).
  plug Plug.Static, at: "/js/phoenix", from: {:phoenix, "priv/static"}, only: ~w(phoenix.min.js)

  plug Plug.Static,
    at: "/js/lv",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.min.js)

  plug Plug.Session, @session_options
  plug Webdemo.Router
end
