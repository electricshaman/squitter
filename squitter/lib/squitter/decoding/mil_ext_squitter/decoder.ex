defmodule Squitter.Decoding.MilExtSquitter do
  alias Squitter.{StatsTracker, Decoding.ModeS}

  @df [19, 22]

  defstruct [:df, :msg, :pi, :parity, :checksum, :crc, :icao, :time]

  def decode(time, <<df :: 5, _payload :: 27-bits, pi :: 24-unsigned>> = msg) when df in @df do
    # TODO: Confirm if this DF is actually 56 or 112 bits
    checksum = ModeS.checksum(msg, 56)
    {:ok, icao} = ModeS.icao_address(msg, checksum)
    parity = ModeS.parity(pi, icao)

    StatsTracker.count({:df, df, :decoded})

    %__MODULE__{
      df: df,
      icao: icao,
      pi: pi,
      parity: parity,
      checksum: checksum,
      crc: (if checksum == parity, do: :valid, else: :invalid),
      time: time,
      msg: msg}
  end

  def decode(_time, <<df :: 5, _ :: bits>>) when df in @df do
    StatsTracker.count({:df, df, :decode_failed})
    {:error, :bad_format}
  end

  def decode(_time, _other) do
    {:error, :bad_df}
  end
end
