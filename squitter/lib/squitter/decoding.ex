defmodule Squitter.Decoding do
  use Squitter.Messages
  import Squitter.Decoding.Utils

  def decode(time, msg) when is_list(msg) or is_binary(msg) do
    convert_to_bin(msg)
    |> route(time)
  end

  def route(<<df :: 5, _ :: bits>> = msg, time) do
    case df do
      0  -> ShortAcas.decode(time, msg)
      4  -> AltitudeReply.decode(time, msg)
      5  -> IdentityReply.decode(time, msg)
      11 -> AllCallReply.decode(time, msg)
      16 -> LongAcas.decode(time, msg)
      17 -> ExtSquitter.decode(time, msg) # ADS-B
      18 -> ExtSquitter.decode(time, msg) # ADS-R & TIS-B
      19 -> MilExtSquitter.decode(time, msg)
      20 -> CommBAltitudeReply.decode(time, msg)
      21 -> CommBIdentityReply.decode(time, msg)
      22 -> MilExtSquitter.decode(time, msg)
      24 -> CommDElm.decode(time, msg)
      _  -> %{df: df, time: time, msg: msg}
    end
  end
end
