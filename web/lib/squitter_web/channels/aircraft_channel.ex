defmodule Squitter.Web.AircraftChannel do
  use Squitter.Web, :channel

  def join("aircraft:" <> _key, payload, socket) do
    {:ok, socket}
  end

  def handle_in(other, payload, socket) do
    IO.inspect other, label: "topic"
    IO.inspect payload, label: "payload"

    {:noreply, socket}
  end
end
