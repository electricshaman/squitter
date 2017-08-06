defmodule Squitter.ReportCollector do
  use GenStage
  require Logger

  def start_link do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)

  end
  def report(msg) do
    GenServer.cast(__MODULE__, msg)
  end

  def init(_) do
    {:producer, :ok, buffer_size: 1000}
  end

  def handle_cast({type, data} = msg, state) when is_atom(type) and is_map(data) do
    {:noreply, [msg], state}
  end

  def handle_cast(other, state) do
    Logger.warn("Unrecognized event: #{inspect other}")
    {:noreply, [], state}
  end

  def handle_demand(_demand, state) do
    # TODO: Buffer and dedupe to latest per X time
    {:noreply, [], state}
  end
end
