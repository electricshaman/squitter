defmodule Squitter.Decoding.LongAcas do
  alias Squitter.Decoding.ModeS
  alias Squitter.StatsTracker

  @df 16

  defstruct [:df, :icao, :parity, :msg, :time]

  def decode(time, <<@df :: 5, _control :: 27-bits, _payload :: 56-bits, parity :: 3-bytes>> = msg) do
    checksum = ModeS.checksum(msg, 112)
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
