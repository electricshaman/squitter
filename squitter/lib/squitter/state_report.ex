defmodule Squitter.StateReport do
  @moduledoc """
  Process which holds the current valid state for all active aircraft.
  """
  use GenServer
  require Logger

  @table :state_report

  def start_link do
    GenServer.start_link(__MODULE__, @table, name: __MODULE__)
  end

  # Client

  def state_changed(address, ac_state) do
    GenServer.cast(__MODULE__, {:state_changed, address, ac_state})
  end

  # Server

  def init(table) do
    _ = :ets.new(table, [:named_table, {:write_concurrency, true}])

    # TODO: Implement Bimap data structure (like from boost) for tracking aircraft processes
    # bidirectionally from address -> ref and ref -> address.

    {:ok, {table, {Map.new, Map.new}}}
  end

  def handle_call(:state_report, _from, {table, aircraft}) do
    report =
      :ets.tab2list(table)
      |> Enum.map(fn({_key, state}) -> state end)

    {:reply, %{aircraft: report}, {table, aircraft}}
  end

  def handle_cast({:state_changed, address, ac_state}, {table, aircraft}) do
    :ets.insert(table, {address, ac_state})
    {:noreply, {table, aircraft}}
  end

  def handle_info({:register, Squitter.AircraftRegistry, address, pid, _}, {table, {left, right}}) do
    ref = Process.monitor(pid)
    new_aircraft = {Map.put(left, address, ref), Map.put(right, ref, address)}
    {:noreply, {table, new_aircraft}}
  end

  def handle_info({:unregister, Squitter.AircraftRegistry, address, _pid}, {table, {left, right}}) do
    # Lookup aircraft from the left (address -> ref)
    new_aircraft =
      case Map.pop(left, address) do
        {nil, ^left} -> left
        {ref, new_left} when is_reference(ref) ->
          Logger.debug("Cleaning up for #{address}")
          true = cleanup(table, address, ref)
          new_right = Map.delete(right, ref)
          {new_left, new_right}
      end
    {:noreply, {table, new_aircraft}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, {table, {left, right}}) do
    # Lookup aircraft from the right (ref -> address)
    new_aircraft =
      case Map.pop(right, ref) do
        {nil, ^right} -> right
        {address, new_right} when is_binary(address) ->
          Logger.debug("Cleaning up for #{address}")
          true = cleanup(table, address, ref)
          new_left = Map.delete(left, address)
          {new_left, new_right}
      end
    {:noreply, {table, new_aircraft}}
  end

  defp cleanup(table, address, ref) do
    Process.demonitor(ref, [:flush])
    :ets.delete(table, address)
  end
end
