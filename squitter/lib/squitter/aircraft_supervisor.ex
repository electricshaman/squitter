defmodule Squitter.AircraftSupervisor do
  use Supervisor
  require Logger

  alias Squitter.StatsTracker

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

  Only messages with a verified CRC can create an aircraft. Address/parity replies
  (`crc: :unverified`) recover the address from the CRC remainder, so a corrupted
  frame yields a random address; they're delivered only to aircraft already tracked.
  """
  def dispatch(%{crc: :invalid, df: df}) do
    StatsTracker.count([:crc_failed, :df, df])
    {:error, :invalid_crc}
  end

  def dispatch(%{crc: :unverified, icao: address, df: df} = msg) do
    case Registry.lookup(Squitter.AircraftRegistry, address) do
      [{pid, _}] ->
        GenServer.cast(pid, {:dispatch, msg})

      [] ->
        StatsTracker.count([:unknown_address, :df, df])
        {:error, :unknown_address}
    end
  end

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

  # Private

  defp cast(key, msg) do
    get_aircraft(key)
    |> GenServer.cast(msg)
  end

  defp get_aircraft(key) do
    case Supervisor.start_child(__MODULE__, [key]) do
      {:ok, pid} ->
        Logger.debug("Aircraft #{key} created")
        pid

      {:error, {:already_started, pid}} ->
        pid
    end
  end
end
