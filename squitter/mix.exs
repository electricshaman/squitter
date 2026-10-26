defmodule Squitter.Mixfile do
  use Mix.Project

  def project do
    [
      app: :squitter,
      version: "0.1.0",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Starting the application launches dump1090, so tests run without it.
  defp aliases, do: [test: "test --no-start"]

  def application do
    [extra_applications: [:logger], mod: {Squitter.Application, []}]
  end

  defp deps do
    [
      {:gen_stage, "~> 0.11"},
      {:flow, "~> 0.11"},
      {:poison, "~> 3.1"}
    ]
  end
end
