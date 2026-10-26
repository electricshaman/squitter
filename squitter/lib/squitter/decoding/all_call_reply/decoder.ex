defmodule Squitter.Decoding.AllCallReply do
  import Bitwise
  alias Squitter.StatsTracker
  alias Squitter.Decoding.ModeS

  @df 11

  defstruct [:icao, :df, :msg, :pi, :parity, :checksum, :crc, :interrogator, :time]

  def decode(time, <<@df::5, _payload::27-bits, pi::24-unsigned>> = msg) do
    checksum = ModeS.checksum(msg, 56)
    {:ok, address} = ModeS.icao_address(msg, checksum)
    parity = ModeS.parity(pi, address)

    # PI is the CRC xor the interrogator's code (CL and IC) in the low 7 bits,
    # so only the top 17 bits can be checked. With a nonzero code that's too
    # weak to trust a new address on (noise passes 1 in 2^17), so like readsb,
    # only accept it for an aircraft already tracked.
    overlay = bxor(checksum, pi)
    interrogator = band(overlay, 0x7F)

    crc =
      cond do
        band(overlay, 0xFFFF80) != 0 -> :invalid
        interrogator == 0 -> :valid
        true -> :unverified
      end

    StatsTracker.count({:df, @df, :decoded})

    %__MODULE__{
      df: @df,
      icao: address,
      msg: msg,
      pi: pi,
      parity: parity,
      checksum: checksum,
      crc: crc,
      interrogator: if(crc != :invalid, do: interrogator),
      time: time
    }
  end

  def decode(_time, other) do
    StatsTracker.count({:df, @df, :decode_failed})
    {:unknown, other}
  end
end
