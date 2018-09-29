defmodule Squitter.DemoServer do
  use GenServer
  require Logger

  def start_link(host, port) do
    GenServer.start_link(__MODULE__, [host, port], name: __MODULE__)
  end

  def init([host, port]) do
    {:ok, socket} = :gen_tcp.connect(to_charlist(host), port, [:binary, {:active, :once}])
    {:ok, {socket, []}}
  end

  def handle_info({:tcp, _port, data}, {socket, buffer}) do
    # Hold my beer.
    buffer =
      cond do
        Regex.match?(~r/\]\}$/, data) ->
          # End of document, process it and reset the buffer.

          [data | buffer]
          |> Enum.reverse()
          |> Enum.join()
          |> process()

          []

        Regex.match?(~r/^\{"acList":\[/, data) ->
          # New JSON document, start a new buffer.
          [data]

        true ->
          # In between
          [data | buffer]
      end

    :inet.setopts(socket, [{:active, :once}])
    {:noreply, {socket, buffer}}
  end

  defp process(document) do
    case Poison.Parser.parse(document) do
      {:ok, doc} ->
        Enum.each(doc["acList"], fn m -> Squitter.AircraftSupervisor.dispatch(m) end)

      {:error, reason} ->
        Logger.error("Failed to parse JSON doc from ADSBExchange: #{inspect(reason)}")
    end
  end
end
