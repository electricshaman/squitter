defmodule Squitter.DecoderStage do
  use GenStage
  require Logger

  import Squitter.Decoding, only: [decode: 2]

  def start_link(min, max) do
    Logger.debug "Starting up #{__MODULE__}"
    GenStage.start_link(__MODULE__, {min, max}, name: DecoderStage)
  end

  def init({min, max}) do
    {:producer_consumer, %{}, subscribe_to: [{ModeSInStage, min_demand: min, max_demand: max}]}
  end

  def handle_events(events, _from, state) do
    messages = for {index, frame} <- events, do: decode(frame, index)
    {:noreply, messages, state}
  end
end
