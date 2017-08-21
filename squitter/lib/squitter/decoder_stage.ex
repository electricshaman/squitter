defmodule Squitter.DecoderStage do
  use GenStage
  require Logger

  alias Squitter.AircraftSupervisor

  def start_link(partition) do
    GenStage.start_link(__MODULE__, [partition])
  end

  def init([partition]) do
    Logger.debug "Starting up #{__MODULE__} to pull from partition #{partition}"
    {:consumer, %{}, subscribe_to: [{AvrTcpStage, partition: partition}]}
  end

  def handle_events(events, _from, state) do
    time = System.monotonic_time(:milliseconds)

    counts = Enum.map(events, fn {time, frame} -> Squitter.Decoding.decode(time, frame) end)
             |> Enum.map(&AircraftSupervisor.dispatch/1)
             |> Enum.reduce(%{}, &reduce_totals/2)

    Squitter.StatsTracker.dispatched({time, counts})

    {:noreply, [], state}
  end

  defp reduce_totals(result, totals) do
    received = Map.get(totals, :received, 0) + 1

    dispatched =
      case result do
        :ok ->
          Map.get(totals, :dispatched, 0) + 1
        {:error, _} ->
          Map.get(totals, :dispatched, 0)
      end

    totals
    |> Map.put(:received, received)
    |> Map.put(:dispatched, dispatched)
    |> Map.put(:dropped, received - dispatched)
  end
end
