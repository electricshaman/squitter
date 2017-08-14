defmodule Squitter.Service.Dump1090 do
  use GenServer
  require Logger

  @device_busy Regex.compile!("Device or resource busy", "i")
  @no_device   Regex.compile!("No supported RTLSDR devices found", "i")

  def start_link(path \\ "dump1090", opts \\ []) do
    GenServer.start_link(__MODULE__, [path, opts], name: __MODULE__)
  end

  def start do
    GenServer.call(__MODULE__, :start)
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  def init([path, opts]) do
    case System.find_executable(path) do
      nil ->
        Logger.error("Can't find dump1090!")
        {:stop, :exec_not_found}
      found ->
        gain = opts[:gain] || 45
        port = start_port(found, gain)
        {:ok, %{port: port, path: found, gain: gain}}
    end
  end

  def handle_info({_port, {:data, msg}}, state) do
    Logger.debug("[dump1090] #{msg}")

    cond do
      Regex.match?(@device_busy, msg) ->
        :os.cmd('killall -2 dump1090')
        {:ok, _} = :timer.apply_after(3000, __MODULE__, :start, [])
        {:noreply, %{state | port: nil}}
      Regex.match?(@no_device, msg) ->
        {:stop, {:shutdown, :device_not_found}, state}
      true ->
        {:noreply, state}
    end
  end

  def handle_call(:start, _from, %{path: path, gain: gain, port: nil} = state) do
    port = start_port(path, gain)
    {:reply, :ok, %{state | port: port}}
  end

  def handle_call(:stop, _from, %{port: port} = state) do
    result = Port.close(port)
    Logger.debug("Port closed: #{inspect result}")
    {:reply, result, %{state | port: nil}}
  end

  # Private helpers

  defp start_port(path, gain) do
    Port.open({:spawn, "#{path} --net --fix --gain #{gain} --quiet"}, [:stderr_to_stdout, :binary])
  end
end
