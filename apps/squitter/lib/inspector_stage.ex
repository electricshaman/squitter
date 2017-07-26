defmodule Squitter.InspectorStage do
  use GenStage

  require Logger

  @buffer_size 500

  # TODO: Move this into a separate GenServer.  It shouldn't be part of the GenStage pipeline.

  def start_link do
    Logger.debug "Starting up #{__MODULE__}"
    GenStage.start_link(__MODULE__, :ok, name: InspectorStage)
  end

  def init(_) do
    {:ok, counts} = RingBuffer.new(@buffer_size, 0)
    {:ok, times} = RingBuffer.new(@buffer_size, System.monotonic_time(:milliseconds))

    schedule_next_rate_calc()

    {:consumer, %{rate: 0.0, position: 0, counts: counts, times: times}, subscribe_to: [DispatchStage]}
  end

  def handle_events(events, _from, state) do
    [{time, %{received: received}}] = events

    {:ok, counts} = RingBuffer.set(state.counts, state.position, received)
    {:ok, times} = RingBuffer.set(state.times, state.position, time)

    p = if state.position + 1 >= @buffer_size, do: 0, else: state.position + 1

    {:noreply, [], %{state | counts: counts, times: times, position: p}}
  end

  def handle_info(:calculate_rate, state) do
    times = RingBuffer.to_list(state.times)
    counts = RingBuffer.to_list(state.counts)
    rate = calculate_rate(times, counts)
    Logger.debug "Rate: #{rate}"
    schedule_next_rate_calc()
    {:noreply, [], %{state | rate: rate}}
  end

  defp calculate_rate(times, counts) do
    count = Enum.sum(counts)
    {oldest, newest} = Enum.min_max(times)
    time_diff = (newest - oldest) / 1000
    Float.round(count / time_diff, 1)
  end

  defp schedule_next_rate_calc do
    Process.send_after(self(), :calculate_rate, 5000)
  end
end
