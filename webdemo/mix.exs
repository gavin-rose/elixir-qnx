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
      {:bandit, "~> 1.5"},
      {:plug, "~> 1.16"}
    ]
  end
end
