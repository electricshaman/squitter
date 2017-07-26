defmodule Squitter.Decoding.ShortAcas do
  alias Squitter.Decoding.ModeS

  @df 0

  defstruct [:df, :icao, :msg, :parity, :airborne, :cross_link_capability,
             :sensitivity_level, :reply_information, :altitude_code]

  def decode(<<@df :: 5, _payload :: 27-bits, parity :: 3-bytes>> = msg) do
    checksum = ModeS.checksum(msg, 56)
    icao = ModeS.icao_address(msg, checksum)
    %__MODULE__{df: @df, icao: icao, msg: msg, parity: parity}
  end

  def decode(other) do
    {:unknown, other}
  end
end
