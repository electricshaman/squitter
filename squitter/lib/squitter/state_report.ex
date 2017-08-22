defmodule Squitter.StateReport do
  @moduledoc """
  Process which holds the current valid state for all active aircraft.
  """
  use GenServer

  @table :state_report

  def start_link do
    GenServer.start_link(__MODULE__, @table, name: __MODULE__)
  end

  def init(table) do
    #Registry.register(Squitter.ReportRegistry, "state", [])
    table = :ets.new(table, [:named_table, {:write_concurrency, true}])
    {:ok, {table, %{}}}
  end

  def state_changed(address, state) do
    GenServer.cast(__MODULE__, {:state_changed, address, state})
    #Registry.dispatch(Squitter.ReportRegistry, "state", fn entries ->
    #  for {pid, _} <- entries, do: GenServer.cast(pid, {:state_changed, ac_address, ac_state})
    #end)
  end

  def age_changed(address, age) do
    GenServer.cast(__MODULE__, {:age_changed, address, age})
  end

  def handle_call(:state_report, _from, {table, aircraft}) do
    report =
      :ets.tab2list(table)
      |> Enum.map(fn({_key, state}) -> state end)

    {:reply, %{aircraft: report}, {table, aircraft}}
  end

  def handle_cast({:state_changed, address, state}, {table, aircraft}) do
    :ets.insert(table, {address, state})
    {:noreply, {table, aircraft}}
  end

  def handle_cast({:age_changed, address, age}, {table, aircraft}) do
    case :ets.lookup(table, address) do
      [] ->
        {:noreply, {table, aircraft}}
      [{^address, state}] ->
        new_state = %{state | age: age}
        :ets.insert(table, {address, new_state})
        {:noreply, {table, aircraft}}
    end
  end

  def handle_info({:register, Squitter.AircraftRegistry, address, pid, _}, {table, aircraft}) do
    ref = Process.monitor(pid)
    {:noreply, {table, Map.put(aircraft, ref, address)}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, {table, aircraft}) do
    Process.demonitor(ref)
    case Map.pop(aircraft, ref) do
      {nil, _} ->
        {:noreply, {table, aircraft}}
      {address, new_aircraft} ->
        true = :ets.delete(table, address)
        {:noreply, {table, new_aircraft}}
    end
  end
end
