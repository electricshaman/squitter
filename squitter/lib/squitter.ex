defmodule Squitter do
  @moduledoc """
  Documentation for Squitter.
  """

  def report do
    call_aircraft(:report)
    |> Enum.map(fn {:ok, a} -> a end)
    |> Enum.sort_by(fn a -> a.age end)
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
    :pg2.get_members(:aircraft)
  end
end
