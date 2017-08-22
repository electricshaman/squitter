defmodule Squitter.Web.AircraftChannel do
  use Squitter.Web, :channel
  require Logger

  def join("aircraft:" <> _key, _payload, socket) do
    {:ok, socket}
  end

  def handle_in("roger", payload, socket) do
    push(socket, "state_report", %{aircraft: state_reports()})

    schedule_report_push()
    {:reply, {:ok, payload}, socket}
  end

  def handle_in(_other, _payload, socket) do
    {:noreply, socket}
  end

  def handle_info(:send_report, socket) do
    # We only want to send position history on the first message so we strip it here
    reports =
      state_reports()
      |> Enum.map(fn(r) -> Map.delete(r, :position_history) end)

    push(socket, "state_report", %{aircraft: reports})

    schedule_report_push()
    {:noreply, socket}
  end

  defp state_reports do
    :ets.tab2list(:state_report)
    |> Enum.map(fn({_key, state}) -> state end)
  end

  defp schedule_report_push do
    Process.send_after(self(), :send_report, 1000)
  end
end
