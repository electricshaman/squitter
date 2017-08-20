defmodule Squitter.Decoding.AltitudeReply do
  alias Squitter.Decoding.ModeS
  alias Squitter.StatsTracker

  @df 4

  defstruct [:df, :icao, :time, :parity, :msg]

  def decode(time, <<@df :: 5, _payload :: 27-bits, parity :: 3-bytes>> = msg) do
    checksum = ModeS.checksum(msg, 56)
    icao = ModeS.icao_address(msg, checksum)

    StatsTracker.count({:df, @df, :decoded})

    %__MODULE__{
      df: @df,
      icao: icao,
      msg: msg,
      parity: parity,
      time: time}
  end

  def decode(_time, other) do
    StatsTracker.count({:df, @df, :decode_failed})
    {:unknown, other}
  end
end
