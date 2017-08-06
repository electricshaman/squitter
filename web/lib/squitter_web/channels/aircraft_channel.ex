defmodule Squitter.Web.AircraftChannel do
  use Squitter.Web, :channel

  require Logger

  def join("aircraft:" <> _key, payload, socket) do
    {:ok, socket}
  end

  def handle_in(other, payload, socket) do
    {:noreply, socket}
  end
end
