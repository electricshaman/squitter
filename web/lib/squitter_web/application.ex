defmodule Squitter.Web.Application do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec

    Logger.debug("Squitter web starting up")

    children = [
      supervisor(Squitter.Web.Endpoint, [])
    ]

    opts = [strategy: :one_for_one, name: Squitter.Web.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    Squitter.Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
