defmodule Webdemo.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT", "4000"))

    Application.put_env(:webdemo, Webdemo.Endpoint,
      url: [host: "localhost"],
      http: [ip: {0, 0, 0, 0}, port: port],
      adapter: Bandit.PhoenixAdapter,
      server: true,
      secret_key_base: String.duplicate("webdemo-qnx-", 6),
      live_view: [signing_salt: "qnxsalt0"],
      pubsub_server: Webdemo.PubSub,
      check_origin: false,
      render_errors: [formats: [html: Webdemo.ErrorHTML], layout: false]
    )

    children = [
      {Phoenix.PubSub, name: Webdemo.PubSub},
      Webdemo.Analyzer,
      Webdemo.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Webdemo.Supervisor)
  end
end
