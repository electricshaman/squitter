defmodule Squitter.Decoding.CommBAltitudeReply do
  alias Squitter.StatsTracker
  alias Squitter.Decoding.ModeS

  @df 20

  defstruct [:df, :icao, :msg, :checksum, :parity, :pi, :crc, :time]

  # TODO: Rename pi to ap.  pi is on the uplink
  def decode(time, <<@df::5, _control::27-bits, _payload::56-bits, pi::24-unsigned>> = msg) do
    checksum = ModeS.checksum(msg, 112)
    {:ok, address} = ModeS.icao_address(msg, checksum)
    parity = ModeS.parity(pi, address)

    StatsTracker.count({:df, @df, :decoded})

    %__MODULE__{
      df: @df,
      icao: address,
      checksum: checksum,
      parity: parity,
      pi: pi,
      # The address is recovered from the AP field, so the CRC can only be checked
      # against a known address. See AircraftSupervisor.dispatch/1.
      crc: :unverified,
      time: time,
      msg: msg
    }
  end

  def decode(_time, other) do
    StatsTracker.count({:df, @df, :decode_failed})
    {:unknown, other}
  end
end
