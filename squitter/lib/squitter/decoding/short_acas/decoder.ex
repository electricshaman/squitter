defmodule Squitter.Decoding.ShortAcas do
  alias Squitter.Decoding.ModeS
  alias Squitter.StatsTracker

  @df 0

  defstruct [:df, :icao, :msg, :parity, :airborne, :cross_link_capability,
             :sensitivity_level, :reply_information, :altitude_code, :time,
             :crc, :pi, :checksum]

  def decode(time, <<@df :: 5, _payload :: 27-bits, pi :: 24-unsigned>> = msg) do
    checksum = ModeS.checksum(msg, 56)
    {:ok, icao} = ModeS.icao_address(msg, checksum)
    parity = ModeS.parity(pi, icao)

    StatsTracker.count({:df, @df, :decoded})

    %__MODULE__{
      df: @df,
      icao: icao,
      msg: msg,
      parity: parity,
      pi: pi,
      checksum: checksum,
      crc: (if checksum == parity, do: :valid, else: :invalid),
      time: time}
  end

  def decode(_time, other) do
    StatsTracker.count({:df, @df, :decode_failed})
    {:unknown, other}
  end
end
