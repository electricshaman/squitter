defmodule Squitter.Application do
  @moduledoc false

  use Application
  require Logger

  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    Logger.debug("Squitter application starting")

    site = Application.get_env(:squitter, :site) || []

    children =
      [
        worker(Squitter.StateReport, []),
        registry_supervisor(Squitter.AircraftRegistry, :unique, [Squitter.StateReport]),
        worker(Squitter.Site, [site[:location], site[:range_limit]]),
        worker(Squitter.MasterLookup, []),
        worker(Squitter.StatsTracker, [10000]),
        supervisor(Squitter.AircraftSupervisor, []),
        # worker(Squitter.DemoServer, ["pub-vrs.adsbexchange.com", 32001])
        supervisor(Squitter.DecodingSupervisor, [false])
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Squitter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp registry_supervisor(name, keys, listeners) do
    supervisor(
      Registry,
      [keys, name, [partitions: System.schedulers_online(), listeners: listeners]],
      id: name
    )
  end
end
