defmodule Squitter.Web.MapChannel do
  use Squitter.Web, :channel

  require Logger

  def join(topic, payload, socket) do
    {:ok, socket}
  end

  def handle_in(other, payload, socket) do
    {:noreply, socket}
  end
end
