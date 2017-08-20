defmodule Squitter.Decoding.CommDElm do
  alias Squitter.StatsTracker

  @df 24

  defstruct [:df, :msg, :time]

  def decode(time, <<@df :: 5, _ :: bits>> = msg) do
    StatsTracker.count({:df, @df, :decoded})
    %__MODULE__{
      df: @df,
      msg: msg,
      time: time}
  end

  def decode(_time, other) do
    StatsTracker.count({:df, @df, :decode_failed})
    {:unknown, other}
  end
end
