defmodule Squitter.DecodingSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    config = get_decoding_config()
    avr_host = config[:avr_host] || "localhost"
    avr_port = config[:avr_port] || 30002
    dump1090_path = config[:dump1090_path]

    # TODO: Convert to new spec structure in 1.5.

    children = [
      dump1090_worker(dump1090_path, avr_host),
      worker(Squitter.AvrTcpStage, [avr_host, avr_port]),
      worker(Squitter.DecoderStage, [500, 1000]),
      worker(Squitter.DispatchStage, [500, 1000])
    ] |> List.flatten

    supervise(children, strategy: :rest_for_one, max_restarts: 100, max_seconds: 3)
  end

  def get_decoding_config do
    Application.get_env(:squitter, :decoding) || []
  end

  def dump1090_worker(dump1090_path, avr_host) do
    # If we're pointing to localhost, then we need to startup an instance of dump1090.
    if avr_host == "localhost" do
      worker(Squitter.Service.Dump1090, [dump1090_path])
    else
      []
    end
  end
end
