defmodule Squitter.Decoding.MilExtSquitter do
  alias Squitter.StatsTracker

  @df [19, 22]

  defstruct [:df, :msg, :time]

  def decode(time, <<df :: 5, _ :: bits>> = msg) when df in @df do
    StatsTracker.count({:df, df, :decoded})

    %__MODULE__{
      df: df,
      time: time,
      msg: msg}
  end
end
