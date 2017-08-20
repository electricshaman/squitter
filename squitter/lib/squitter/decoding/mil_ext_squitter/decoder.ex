defmodule Squitter.Decoding.MilExtSquitter do
  @df [19, 22]

  defstruct [:df, :msg, :time]

  def decode(time, <<df :: 5, _ :: bits>> = msg) when df in @df do
    %__MODULE__{
      df: df,
      time: time,
      msg: msg}
  end

  def decode(_time, other) do
    {:unknown, other}
  end
end
