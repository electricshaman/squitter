defmodule Squitter.StatsTracker do
  use GenServer
  require Logger

  @buffer_size 500

  def start_link(clock) do
    GenServer.start_link(__MODULE__, [clock], name: __MODULE__)
  end

  def init([clock]) do
    Logger.debug "Starting up #{__MODULE__}"

    counts= :array.new(@buffer_size, default: 0)
    times = :array.new(@buffer_size, default: System.monotonic_time(:milliseconds))

    schedule_tick(clock)

    {:ok, %{
      rate: 0.0,
      clock: clock,
      position: 0,
      totals: %{},
      counts: counts,
      times: times}}
  end

  def handle_cast({:dispatched, counts}, state) do
    {time, %{received: received} = totals} = counts

    new_totals = calculate_totals(totals, state.totals)

    counts = :array.set(state.position, received, state.counts)
    times = :array.set(state.position, time, state.times)
    next_position = if state.position + 1 >= @buffer_size, do: 0, else: state.position + 1

    {:noreply, %{state | totals: new_totals, counts: counts, times: times, position: next_position}}
  end

  def handle_info(:tick, state) do
    times = :array.to_list(state.times)
    counts = :array.to_list(state.counts)

    rate = calculate_rate(times, counts)

    Logger.debug(fn -> "[stats] #{format_stats({rate, state.totals})}" end)

    schedule_tick(state.clock)

    {:noreply, %{state | rate: rate}}
  end

  defp calculate_rate(times, counts) do
    count = Enum.sum(counts)
    {oldest, newest} = Enum.min_max(times)
    time_diff = (newest - oldest) / 1000

    if time_diff > 0, do: Float.round(count / time_diff, 1), else: 0.0
  end

  defp calculate_totals(totals, acc) do
    Map.merge(totals, acc, fn(_k, ct, ca) -> ct + ca end)
  end

  defp format_stats({rate, totals}) do
    ["rate=#{rate}/sec"|
     Enum.map(totals, fn {k, v} -> "#{k}=#{v}" end)]
     |> Enum.join(",")
  end

  defp schedule_tick(time) do
    Process.send_after(self(), :tick, time)
  end

  ## Client API

  @spec dispatched({number(), map}) :: :ok
  def dispatched({_time, _counts} = event) do
    GenServer.cast(__MODULE__, {:dispatched, event})
  end
end
