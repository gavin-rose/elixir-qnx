defmodule Webdemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :webdemo,
      version: "0.1.0",
      elixir: "~> 1.17",
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Webdemo.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Pure-Elixir/Erlang deps only, so nothing needs a NIF or cross-compile.
  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"}
    ]
  end
end
