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
    # so only the top 17 bits can be checked.
    overlay = bxor(checksum, pi)
    crc = if band(overlay, 0xFFFF80) == 0, do: :valid, else: :invalid

    StatsTracker.count({:df, @df, :decoded})

    %__MODULE__{
      df: @df,
      icao: address,
      msg: msg,
      pi: pi,
      parity: parity,
      checksum: checksum,
      crc: crc,
      interrogator: if(crc == :valid, do: band(overlay, 0x7F)),
      time: time
    }
  end

  def decode(_time, other) do
    StatsTracker.count({:df, @df, :decode_failed})
    {:unknown, other}
  end
end
