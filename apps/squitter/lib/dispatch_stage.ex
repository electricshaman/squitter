defmodule Squitter.DispatchStage do
  use GenStage
  require Logger

  alias Squitter.AircraftSupervisor

  def start_link(min_demand, max_demand) do
    Logger.debug "Starting up #{__MODULE__}"
    GenStage.start_link(__MODULE__, {min_demand, max_demand}, name: DispatchStage)
  end

  def init({min_demand, max_demand}) do
    {:producer_consumer, %{}, subscribe_to: [{DecoderStage, min_demand: min_demand, max_demand: max_demand}]}
  end

  def handle_events(events, _from, state) do
    time = System.monotonic_time(:milliseconds)

    results = events
              |> Enum.map(&AircraftSupervisor.dispatch/1)
              |> Enum.reduce(%{}, &reduce_totals/2)

    stat = {time, results}
    {:noreply, [stat], state}
  end

  defp reduce_totals(result, totals) do
    received = Map.get(totals, :received, 0) + 1
    dispatched = case result do
      :ok -> Map.get(totals, :dispatched, 0) + 1
      {:error, _} -> Map.get(totals, :dispatched, 0)
    end

    totals
    |> Map.put(:received, received)
    |> Map.put(:dispatched, dispatched)
    |> Map.put(:dropped, received - dispatched)
  end
end

