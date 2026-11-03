defmodule Webdemo.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT", "4000"))

    children = [
      {Bandit, plug: Webdemo.Router, scheme: :http, ip: {0, 0, 0, 0}, port: port}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Webdemo.Supervisor)
  end
end
