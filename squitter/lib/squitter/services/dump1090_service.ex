defmodule Squitter.Service.Dump1090 do
  use GenServer
  require Logger

  @device_busy Regex.compile!("Device or resource busy", "i")
  @no_device   Regex.compile!("No supported RTLSDR devices found", "i")

  def start_link(path \\ "dump1090", args \\ []) do
    GenServer.start_link(__MODULE__, [path, args], name: __MODULE__)
  end

  def init([path, args]) do
    case System.find_executable(path) do
      nil ->
        Logger.error("Can't find dump1090!")
        {:stop, :exec_not_found}
      found_path ->
        port = start_port(found_path, args)
        {:ok, %{port: port, path: found_path}}
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

  # Private helpers

  defp start_port(path, args) do
    Port.open({:spawn_executable, path}, [{:args, args}, :stderr_to_stdout, :binary])
  end
end
