defmodule Squitter.Web.AircraftChannel do
  use Squitter.Web, :channel
  require Logger

  def join("aircraft:" <> _key, _payload, socket) do
    {:ok, socket}
  end

  def handle_in("roger", payload, socket) do
    # We only want to send position history on the first message
    push(socket, "state_report", %{aircraft: state_reports(true)})
    schedule_report_push()
    {:reply, {:ok, payload}, socket}
  end

  def handle_in(_other, _payload, socket) do
    {:noreply, socket}
  end

  def handle_info(:send_report, socket) do
    push(socket, "state_report", %{aircraft: state_reports()})
    schedule_report_push()
    {:noreply, socket}
  end

  defp state_reports(position_history \\ false) do
    :ets.tab2list(:state_report)
    |> Enum.map(fn({_key, state}) -> state end)
    |> Enum.map(fn(r) ->
         if position_history, do: r, else: Map.delete(r, :position_history)
       end)
  end

  defp schedule_report_push do
    Process.send_after(self(), :send_report, 1000)
  end
end
