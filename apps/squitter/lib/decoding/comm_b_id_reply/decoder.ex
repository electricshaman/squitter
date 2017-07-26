defmodule Squitter.Decoding.CommBIdentityReply do
  @df 21

  defstruct [:df, :dr, :fs, :id, :squawk, :um, :bds, :msg]

  def decode(<<@df :: 5, _ :: bits>> = msg) do
    %__MODULE__{df: @df, msg: msg}
  end

  def decode(other) do
    {:unknown, other}
  end
end
