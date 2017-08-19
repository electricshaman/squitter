defmodule Squitter.Decoding do
  use Squitter.Messages
  import Squitter.Decoding.Utils

  def decode(time, msg) when is_list(msg) or is_binary(msg) do
    convert_to_bin(msg)
    |> route(time)
  end

  def route(<<df :: 5, _ :: bits>> = msg, time) do
    case df do
      0  -> ShortAcas.decode(msg)
      4  -> AltitudeReply.decode(msg)
      5  -> IdentityReply.decode(msg)
      11 -> AllCallReply.decode(msg)
      16 -> LongAcas.decode(msg)
      17 -> ExtSquitter.decode(time, msg) # ADS-B
      18 -> ExtSquitter.decode(time, msg) # ADS-R & TIS-B
      19 -> MilExtSquitter.decode(msg)
      20 -> CommBAltitudeReply.decode(msg)
      21 -> CommBIdentityReply.decode(msg)
      22 -> MilExtSquitter.decode(msg)
      24 -> CommDElm.decode(msg)
      _  -> %{df: df, time: time, msg: msg}
    end
  end
end
