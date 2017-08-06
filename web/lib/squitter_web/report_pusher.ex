defmodule Squitter.Web.ReportPusher do
  use GenStage

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:consumer, %{}, subscribe_to: [Squitter.ReportCollector]}
  end

  #def handle_subscribe(:producer, [], {#PID<0.353.0>, #Reference<0.1622845777.740556803.65307>}, %{}) do
  #end

  def handle_events(reports, from, state) do
    for {type, msg} <- reports do
      Squitter.Web.Endpoint.broadcast!("aircraft:reports", to_string(type), msg)
    end
    {:noreply, [], state}
  end
end
