defmodule Squitter.Application do
  @moduledoc false

  use Application
  require Logger

  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    Logger.debug "Squitter application starting"

    :pg2.create(:aircraft)

    site = Application.get_env(:squitter, :site) || []

    children = [
      worker(Squitter.ReportCollector, []),
      registry_supervisor(Squitter.AircraftRegistry, :unique),
      worker(Squitter.SiteServer, [site[:location], site[:range_limit]]),
      worker(Squitter.AircraftLookup, []),
      worker(Squitter.StatsTracker, [10000]),
      supervisor(Squitter.AircraftSupervisor, []),
      supervisor(Squitter.DecodingSupervisor, [])
    ] |> List.flatten

    opts = [strategy: :one_for_one, name: Squitter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp registry_supervisor(name, keys) do
    supervisor(Registry, [keys, name, [partitions: System.schedulers_online()]], id: name)
  end
end
