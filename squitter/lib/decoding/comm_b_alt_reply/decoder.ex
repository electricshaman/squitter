defmodule Squitter.Decoding.CommBAltitudeReply do
  @df 20

  defstruct [:df, :msg]

  def decode(<<@df :: 5, _ :: bits>> = msg) do
    %__MODULE__{df: @df, msg: msg}
  end

  def decode(other) do
    {:unknown, other}
  end
end
