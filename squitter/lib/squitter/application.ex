defmodule Squitter.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec, warn: false

  def start(_type, _args) do

    :pg2.create(:aircraft)

    children = [
      pubsub(),
      registry_supervisor(Squitter.AircraftRegistry, :unique),
      worker(Squitter.StatTracker, [10000]),
      supervisor(Squitter.AircraftSupervisor, []),
      supervisor(Squitter.DecodingSupervisor, [])
    ] |> List.flatten

    opts = [strategy: :one_for_one, name: Squitter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp pubsub do
    if Application.get_env(:squitter, :start_pubsub) do
      [supervisor(Phoenix.PubSub.PG2, [Squitter.PubSub, []])]
    else
      []
    end
  end

  defp registry_supervisor(name, keys) do
    supervisor(Registry, [keys, name, [partitions: System.schedulers_online()]], id: name)
  end
end
