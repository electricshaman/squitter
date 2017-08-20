defmodule Squitter.Decoding.CommBIdentityReply do
  alias Squitter.StatsTracker

  @df 21

  defstruct [:df, :time, :dr, :fs, :id, :squawk, :um, :bds, :msg]

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
