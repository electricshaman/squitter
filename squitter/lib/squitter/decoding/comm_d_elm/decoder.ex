defmodule Squitter.Decoding.CommDElm do
  alias Squitter.StatsTracker
  alias Squitter.Decoding.ModeS

  @df 24

  defstruct [:df, :msg, :time, :icao, :checksum, :parity, :pi, :crc]

  def decode(time, <<@df::5, _control::27-bits, _payload::56-bits, pi::24-unsigned>> = msg) do
    checksum = ModeS.checksum(msg, 112)
    {:ok, icao} = ModeS.icao_address(msg, checksum)
    parity = ModeS.parity(pi, icao)

    StatsTracker.count({:df, @df, :decoded})

    %__MODULE__{
      df: @df,
      icao: icao,
      parity: parity,
      pi: pi,
      checksum: checksum,
      crc: if(checksum == pi, do: :valid, else: :invalid),
      msg: msg,
      time: time
    }
  end

  def decode(_time, other) do
    StatsTracker.count({:df, @df, :decode_failed})
    {:unknown, other}
  end
end
