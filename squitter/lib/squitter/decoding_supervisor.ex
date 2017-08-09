defmodule Squitter.DecodingSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      worker(Squitter.Service.Dump1090, [[path: "/home/jeff/Code/dump1090/dump1090"]]),
      worker(Squitter.AvrTcpStage, ["localhost", 30002]),
      worker(Squitter.DecoderStage, [500, 1000]),
      worker(Squitter.DispatchStage, [500, 1000])
    ]

    supervise(children, strategy: :rest_for_one, max_restarts: 500, max_seconds: 3)
  end
end
