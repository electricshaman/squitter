defmodule Squitter.Decoding.CommBAltitudeReply do
  alias Squitter.StatsTracker

  @df 20

  defstruct [:df, :msg, :time]

  def decode(time, <<@df :: 5, _ :: bits>> = msg) do
    StatsTracker.count({:df, @df, :decoded})

    %__MODULE__{
      df: @df,
      time: time,
      msg: msg}
  end

  def decode(_time, other) do
    StatsTracker.count({:df, @df, :decode_failed})
    {:unknown, other}
  end
end
