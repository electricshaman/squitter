defmodule Squitter.Decoding.IdentityReply do
  alias Squitter.Decoding.ModeS
  alias Squitter.StatsTracker

  @df 5

  defstruct [:df, :icao, :parity, :pi, :icao, :checksum, :crc, :msg, :time]

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
