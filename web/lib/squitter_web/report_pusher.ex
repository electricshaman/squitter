defmodule Squitter.Web.ReportPusher do
  use GenStage

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:consumer, %{}, subscribe_to: [{Squitter.ReportCollector, interval: 1000}]}
  end

  def handle_subscribe(:producer, opts, from, producers) do
    pending = opts[:max_demand] || 1000
    interval = opts[:interval] || 5000

    producers = Map.put(producers, from, {pending, interval})
    producers = ask_and_schedule(producers, from)

    {:manual, producers}
  end

  def handle_cancel(_, from, producers) do
    {:noreply, [], Map.delete(producers, from)}
  end


  def handle_events(reports, from, producers) do
    producers = Map.update!(producers, from, fn {pending, interval} ->
      {pending + length(reports), interval}
    end)

    for {type, msg} <- reports do
      Squitter.Web.Endpoint.broadcast!("aircraft:reports", to_string(type), msg)
    end

    {:noreply, [], producers}
  end

  def handle_info({:ask, from}, producers) do
    {:noreply, [], ask_and_schedule(producers, from)}
  end

  defp ask_and_schedule(producers, from) do
    case producers do
      %{^from => {pending, interval}} ->
        GenStage.ask(from, pending)
        Process.send_after(self(), {:ask, from}, interval)
        Map.put(producers, from, {0, interval})
      %{} ->
        producers
    end
  end
end
