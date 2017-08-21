defmodule Squitter.Site do
  use GenServer

  @default_location     [40.7950914, -98.9153411] # Somewhere in Kansas
  @default_range_limit  300 # NM

  def start_link(location, range_limit) do
    GenServer.start_link(__MODULE__, [location, range_limit], name: __MODULE__)
  end

  def init([location, range_limit]) do
    {:ok, %{
      location: location || @default_location,
      range_limit: range_limit || @default_range_limit}}
  end

  def range_limit do
    GenServer.call(__MODULE__, :get_range_limit)
  end

  def range_limit(new_limit) do
    GenServer.call(__MODULE__, {:set_range_limit, new_limit})
  end

  def location do
    GenServer.call(__MODULE__, :get_location)
  end

  def handle_call(:get_range_limit, _from, state) do
    {:reply, {:ok, state.range_limit}, state}
  end

  def handle_call({:set_range_limit, new_limit}, _from, state) do
    {:reply, {:ok, new_limit}, %{state | range_limit: new_limit}}
  end

  def handle_call(:get_location, _from, state) do
    {:reply, {:ok, state.location}, state}
  end
end
