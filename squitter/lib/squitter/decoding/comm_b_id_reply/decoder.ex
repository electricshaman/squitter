defmodule Squitter.Decoding.CommBIdentityReply do
  alias Squitter.StatsTracker
  alias Squitter.Decoding.ModeS

  @df 21

  defstruct [
    :df,
    :icao,
    :checksum,
    :pi,
    :parity,
    :crc,
    :time,
    :dr,
    :fs,
    :id,
    :squawk,
    :um,
    :bds,
    :msg
  ]

  def decode(time, <<@df::5, _control::27-bits, _payload::56-bits, pi::24-unsigned>> = msg) do
    checksum = ModeS.checksum(msg, 112)
    {:ok, address} = ModeS.icao_address(msg, checksum)
    parity = ModeS.parity(pi, address)

    StatsTracker.count({:df, @df, :decoded})

    %__MODULE__{
      df: @df,
      icao: address,
      checksum: checksum,
      pi: pi,
      parity: parity,
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
