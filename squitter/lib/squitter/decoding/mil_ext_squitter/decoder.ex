defmodule Squitter.Decoding.MilExtSquitter do
  alias Squitter.{StatsTracker, Decoding.ModeS}

  @df [19, 22]

  defstruct [:df, :msg, :pi, :checksum, :crc, :icao, :time]

  def decode(time, <<df::5, af::3, _::80, pi::24-unsigned>> = msg) when df in @df do
    checksum = ModeS.checksum(msg, 112)

    # DF19 with AF = 0 is laid out like DF17: plain address and a full CRC.
    # Other AF values and DF22 are military formats with no public spec, so
    # neither the address nor the parity scheme is known.
    {icao, crc} =
      case {df, af} do
        {19, 0} ->
          {:ok, icao} = ModeS.icao_address(msg, checksum)
          {icao, if(checksum == pi, do: :valid, else: :invalid)}

        _ ->
          {nil, :unverified}
      end

    StatsTracker.count({:df, df, :decoded})

    %__MODULE__{
      df: df,
      icao: icao,
      pi: pi,
      checksum: checksum,
      crc: crc,
      time: time,
      msg: msg
    }
  end

  def decode(_time, <<df::5, _::bits>>) when df in @df do
    StatsTracker.count({:df, df, :decode_failed})
    {:error, :bad_format}
  end

  def decode(_time, _other) do
    {:error, :bad_df}
  end
end
