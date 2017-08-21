defmodule Squitter.AvrTcpStage do
  use GenStage
  require Logger
  alias Squitter.AVR
  import Squitter.Decoding.Utils, only: [hex_to_bin: 1]

  @max_conn_attempts 10

  def start_link(host, port, partitions) do
    Logger.debug "Starting up #{__MODULE__}"
    GenStage.start_link(__MODULE__, [host, port, partitions], name: AvrTcpStage)
  end

  def init([host, port, partitions]) do
    send(self(), :connect)

    hash_function = fn({t,f} = m) ->
      {:ok, address} = Squitter.Decoding.ModeS.icao_address(f)
      partition = :erlang.phash2(address, length(partitions))
      {m, partition}
    end

    {:producer, %{
      host: host,
      port: port,
      socket: nil,
      attempts: @max_conn_attempts - 1,
      buffer: []},
      dispatcher: {GenStage.PartitionDispatcher, hash: hash_function, partitions: partitions}}
  end

  def handle_info({:tcp, _socket, data}, %{buffer: buffer} = state) do
    time = System.monotonic_time(:microseconds)

    {frames, next_buffer} = AVR.split_frames(buffer ++ data)

    # Use time + index as a logical ordering value
    indexed_frames =
      frames
      |> Enum.map(&hex_to_bin/1)
      |> Enum.with_index(time)
      |> Enum.map(fn {frame, time} -> {time, frame} end)

    {:noreply, indexed_frames, %{state | buffer: next_buffer}}
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
    {:noreply, [], state}
  end
end
