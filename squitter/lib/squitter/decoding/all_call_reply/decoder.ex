defmodule Squitter.Decoding.AllCallReply do
  alias Squitter.StatsTracker

  @df 11

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
