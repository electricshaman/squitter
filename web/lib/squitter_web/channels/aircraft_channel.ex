defmodule Squitter.Web.AircraftChannel do
  use Squitter.Web, :channel

  require Logger

  def join("aircraft:" <> _key, payload, socket) do
    Phoenix.PubSub.subscribe(Squitter.PubSub, "aircraft")
    {:ok, socket}
  end

  def handle_in(other, payload, socket) do
    IO.inspect other, label: "topic"
    IO.inspect payload, label: "payload"

    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    push socket, "report", msg
    {:noreply, socket}
  end
end
