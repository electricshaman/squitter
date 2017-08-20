defmodule Squitter.Decoding.AllCallReply do
  @df 11

  defstruct [:df, :msg, :time]

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
