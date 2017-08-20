defmodule Squitter.Decoding.CommBAltitudeReply do
  @df 20

  defstruct [:df, :msg, :time]

  def decode(time, <<@df :: 5, _ :: bits>> = msg) do
    %__MODULE__{df: @df,
      time: time,
      msg: msg}
  end

  def decode(_time, other) do
    {:unknown, other}
  end
end
