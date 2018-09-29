defmodule Squitter.Decoding.AltitudeReply do
  alias Squitter.Decoding.ModeS
  alias Squitter.StatsTracker

  @df 4

  defstruct [:df, :icao, :time, :pi, :parity, :checksum, :msg, :crc]

  def decode(time, <<@df::5, _payload::27-bits, pi::24-unsigned>> = msg) do
    checksum = ModeS.checksum(msg, 56)
    {:ok, icao} = ModeS.icao_address(msg, checksum)
    parity = ModeS.parity(pi, icao)

    StatsTracker.count({:df, @df, :decoded})

    %__MODULE__{
      df: @df,
      icao: icao,
      msg: msg,
      pi: pi,
      parity: parity,
      time: time,
      checksum: checksum,
      crc: if(checksum == parity, do: :valid, else: :invalid)
    }
  end

  def decode(_time, other) do
    StatsTracker.count({:df, @df, :decode_failed})
    {:unknown, other}
  end
end
