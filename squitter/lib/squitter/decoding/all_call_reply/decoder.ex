defmodule Squitter.Decoding.AllCallReply do
  alias Squitter.StatsTracker
  alias Squitter.Decoding.ModeS

  @df 11

  defstruct [:icao, :df, :msg, :pi, :parity, :checksum, :crc, :time]

  def decode(time, <<@df :: 5, _payload :: 27-bits, pi :: 24-unsigned>> = msg) do
    checksum = ModeS.checksum(msg, 56)
    {:ok, address} = ModeS.icao_address(msg, checksum)
    parity = ModeS.parity(pi, address)

    StatsTracker.count({:df, @df, :decoded})

    %__MODULE__{
      df: @df,
      icao: address,
      msg: msg,
      pi: pi,
      parity: parity,
      checksum: checksum,
      crc: (if checksum == pi, do: :valid, else: :invalid),
      time: time}
  end

  def decode(_time, other) do
    StatsTracker.count({:df, @df, :decode_failed})
    {:unknown, other}
  end
end
