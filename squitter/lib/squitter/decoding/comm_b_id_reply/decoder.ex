defmodule Squitter.Decoding.CommBIdentityReply do
  @df 21

  defstruct [:df, :time, :dr, :fs, :id, :squawk, :um, :bds, :msg]

  def decode(time, <<@df :: 5, _ :: bits>> = msg) do
    %__MODULE__{
      df: @df,
      msg: msg,
      time: time}
  end

  def decode(other) do
    {:unknown, other}
  end
end
