defmodule Squitter.Decoding.LongAcas do
  alias Squitter.Decoding.ModeS

  @df 16

  defstruct [:df, :icao, :parity, :msg]

  def decode(<<@df :: 5, _control :: 27-bits, _payload :: 56-bits, parity :: 3-bytes>> = msg) do
    checksum = ModeS.checksum(msg, 112)
    icao = ModeS.icao_address(msg, checksum)
    %__MODULE__{df: @df, icao: icao, msg: msg, parity: parity}
  end

  def decode(other) do
    {:unknown, other}
  end
end
