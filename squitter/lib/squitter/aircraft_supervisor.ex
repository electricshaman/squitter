defmodule Squitter.AircraftSupervisor do
  use Supervisor
  require Logger

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      worker(Squitter.Aircraft, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  @doc """
  Attempt to dispatch `msg` to an aircraft process using one or more key values found in the message itself.
  If no suitable keys are found, the message will be dropped.
  """
  def dispatch(%{icao: address} = msg) do
    dispatch(address, msg)
  end

  def dispatch(%{"Icao" => address} = msg) do
    dispatch(address, msg)
  end

  def dispatch(_other) do
    # Nothing available in the message to locate the aircraft, drop the message.
    {:error, :unroutable}
  end

  @doc """
  Dispatch the decoded `msg` to an aircraft process registered to `address`.
  """
  def dispatch(key, msg) do
    cast(key, {:dispatch, msg})
  end

  def call_all_aircraft(request) do
    aircraft_pids()
    |> Enum.map(fn pid -> GenServer.call(pid, request) end)
  end

  def cast_all_aircraft(request) do
    aircraft_pids()
    |> Enum.each(fn pid -> GenServer.cast(pid, request) end)
    :ok
  end

  def aircraft_pids do
    Supervisor.which_children(__MODULE__)
    |> Enum.map(fn({_, pid, _, _}) -> pid end)
  end

  # Private

  defp cast(key, msg) do
    get_aircraft(key)
    |> GenServer.cast(msg)
  end

  defp call(key, msg) do
    get_aircraft(key)
    |> GenServer.call(msg)
  end

  defp get_aircraft(key) do
    case Supervisor.start_child(__MODULE__, [key]) do
      {:ok, pid} ->
        Logger.debug "Aircraft #{key} created"
        pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
