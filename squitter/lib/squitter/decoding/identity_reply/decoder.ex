defmodule Squitter.Decoding.IdentityReply do
  alias Squitter.Decoding.ModeS

  @df 5

  defstruct [:df, :icao, :parity, :msg, :time]

  def decode(time, <<@df :: 5, _payload :: 27-bits, parity :: 3-bytes>> = msg) do
    checksum = ModeS.checksum(msg, 56)
    icao = ModeS.icao_address(msg, checksum)

    %__MODULE__{
      df: @df,
      icao: icao,
      msg: msg,
      parity: parity,
      time: time}
  end

  def decode(_time, other) do
    {:unknown, other}
  end
end
