defmodule Squitter.AvrTcpStage do
  use GenStage

  require Logger

  alias Squitter.{AVR, Decoding}

  def start_link(host, port) do
    Logger.debug "Starting up #{__MODULE__}"
    GenStage.start_link(__MODULE__, [host, port], name: ModeSInStage)
  end

  def init([host, port]) do
    {:ok, _socket} = :gen_tcp.connect(to_charlist(host), port, [{:active, true}])
    {:producer, []}
  end

  def handle_info({:tcp, _socket, data}, buffer) do
    time = System.monotonic_time(:milliseconds)
    {frames, next_buffer} = AVR.split_frames(buffer ++ data)
    frames = Enum.with_index(frames)
             |> Enum.map(fn {f,i} -> {time+i, f} end)
    {:noreply, frames, next_buffer}
  end

  def handle_info({:tcp_closed, socket}, buffer) do
    :gen_tcp.close(socket)
    {:stop, {:shutdown, :tcp_closed}, buffer}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state} # TODO: Buffer demand
  end
end
