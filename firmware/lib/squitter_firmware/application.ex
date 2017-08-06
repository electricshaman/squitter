defmodule Squitter.Firmware.Application do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.debug "Squitter firmware application starting"
    # Start these in order if not done so already by bootloader
    Application.ensure_all_started(:squitter)
    Application.ensure_all_started(:squitter_web)

    children = [
    ]

    opts = [strategy: :one_for_one, name: Squitter.Firmware.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
