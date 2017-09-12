defmodule Squitter.DecodingSupervisor do
  use Supervisor

  def start_link(net_only \\ false) do
    Supervisor.start_link(__MODULE__, net_only, name: __MODULE__)
  end

  def init(net_only) do
    config = get_decoding_config()
    dump1090_path = config[:dump1090_path]
    avr_host = config[:avr_host] || "localhost"
    avr_port = config[:avr_port] || 30002
    gain = config[:gain] || 45

    dump1090_worker =
      if net_only do
        worker(Squitter.Service.Dump1090, [dump1090_path, ["--net-only"]])
      else
        # If we're pointing to localhost, then we need to startup an instance of dump1090.
        if avr_host == "localhost" do
          worker(Squitter.Service.Dump1090, [dump1090_path, ["--net", "--fix", "--gain", to_string(gain), "--quiet"]])
        else
          []
        end
      end

    partitions = Enum.to_list(0..4)

    # TODO: Convert to new spec structure in 1.5.

    children = [
      dump1090_worker,
      worker(Squitter.AvrTcpStage, [avr_host, avr_port, partitions]),
      setup_decoders(partitions),
    ] |> List.flatten

    supervise(children, strategy: :one_for_all, max_restarts: 10, max_seconds: 3)
  end

  defp get_decoding_config do
    Application.get_env(:squitter, :decoding) || []
  end

  defp setup_decoders(partitions) do
    partitions
    |> Enum.with_index
    |> Enum.map(fn({p, i}) ->
         worker(Squitter.DecoderStage, [p], id: "avr_decoder_#{i}")
       end)
  end
end
