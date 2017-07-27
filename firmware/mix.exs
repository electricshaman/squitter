defmodule Squitter.Firmware.Mixfile do
  use Mix.Project

  @target System.get_env("MIX_TARGET") || "host"

  Mix.shell.info([:green, """
  Mix environment
    MIX_TARGET:   #{@target}
    MIX_ENV:      #{Mix.env}
  """, :reset])

  def project do
    [app: :squitter_firmware,
     version: "0.1.0",
     elixir: "~> 1.4.0",
     target: @target,
     archives: [nerves_bootstrap: "~> 0.4"],
     deps_path: "deps/#{@target}",
     build_path: "_build/#{@target}",
     config_path: "config/config.exs",
     lockfile: "mix.lock.#{@target}",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(@target),
     deps: deps()]
  end

  def application, do: application(@target)

  def application("host") do
    [mod: {Squitter.Firmware.Application, []},
     extra_applications: [:logger]]
  end

  def application(_target) do
    [mod: {Squitter.Firmware.Application, []},
     extra_applications: [:logger]]
  end

  def deps do
    [{:nerves, path: "../../nerves", override: true},
     {:squitter_web, path: "../web"}
    ] ++
    deps(@target)
  end

  def deps("host"), do: []
  def deps(target) do
    [system(target),
     {:bootloader, "~> 0.1"},
     {:nerves_runtime, "~> 0.4"}]
  end

  def system("rpi3"), do: {:nerves_system_rpi3_sdr, path: "../../nerves_systems/nerves_system_rpi3_sdr", runtime: false}
  #def system("rpi0"), do: {:nerves_system_rpi0, ">= 0.0.0", runtime: false}
  def system(target), do: Mix.raise "Unknown MIX_TARGET: #{target}"

  # We do not invoke the Nerves Env when running on the Host
  def aliases("host"), do: []
  def aliases(_target) do
    ["deps.precompile": ["nerves.precompile", "deps.precompile"],
     "deps.loadpaths":  ["deps.loadpaths", "nerves.loadpaths"]]
  end

end
