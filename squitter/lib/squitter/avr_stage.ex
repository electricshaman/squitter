defmodule Squitter.AvrTcpStage do
  use GenStage
  require Logger
  alias Squitter.AVR

  @max_attempts 10

  def start_link(host, port) do
    Logger.debug "Starting up #{__MODULE__}"
    GenStage.start_link(__MODULE__, [host, port], name: ModeSInStage)
  end

  def init([host, port]) do
    state = %{host: host, port: port, socket: nil, buffer: []}

    send(self(), :connect)

    {:producer, %{
      host: host,
      port: port,
      socket: nil,
      attempts: @max_attempts - 1,
      buffer: []}}
  end

  def handle_info({:tcp, _socket, data}, %{buffer: buffer} = state) do
    time = System.monotonic_time(:milliseconds)
    {frames, next_buffer} = AVR.split_frames(buffer ++ data)
    frames = Enum.with_index(frames)
             |> Enum.map(fn {f,i} -> {time+i, f} end)
    {:noreply, frames, %{state | buffer: next_buffer}}
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    :gen_tcp.close(socket)
    {:stop, {:shutdown, :tcp_closed}, state}
  end

  def handle_info(:connect, %{attempts: 0} = state) do
    {:stop, {:shutdown, :connect_failed}, state}
  end

  def handle_info(:connect, %{host: host, port: port, socket: nil, attempts: attempts} = state) do
    case :gen_tcp.connect(to_charlist(host), port, [{:active, true}]) do
      {:ok, socket} ->
        {:noreply, [], %{state | socket: socket}}
      {:error, reason} ->
        Logger.warn("Failed to connect to AVR source at #{host}:#{port}: #{inspect reason} (#{attempts} attempts remaining)")
        Process.send_after(self(), :connect, 1000)
        {:noreply, [], %{state | attempts: attempts - 1}}
    end
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state} # TODO: Buffer demand
  end
end
