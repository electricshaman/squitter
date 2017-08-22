defmodule Squitter do
  @moduledoc """
  Documentation for Squitter.
  """

  defp state_report do
    report =
      :ets.tab2list(:state_report)
      |> Enum.map(fn({_key, state}) -> state end)

    %{aircraft: report}
  end

  defp call_aircraft(request) do
    aircraft_pids()
    |> Enum.map(fn pid -> GenServer.call(pid, request) end)
  end

  defp cast_aircraft(request) do
    aircraft_pids()
    |> Enum.each(fn pid -> GenServer.cast(pid, request) end)
    :ok
  end

  defp aircraft_pids do
    Supervisor.which_children(Squitter.AircraftSupervisor)
    |> Enum.map(fn({_, pid, _, _}) -> pid end)
  end
end
