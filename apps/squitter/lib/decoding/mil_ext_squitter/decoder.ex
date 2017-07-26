defmodule Squitter.Decoding.MilExtSquitter do
  @df [19, 22]

  defstruct [:df, :msg]

  def decode(<<df :: 5, _ :: bits>> = msg) when df in @df do
    %__MODULE__{df: df, msg: msg}
  end

  def decode(other) do
    {:unknown, other}
  end
end
