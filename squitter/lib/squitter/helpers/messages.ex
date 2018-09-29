defmodule Squitter.Messages do
  defmacro __using__(_) do
    quote do
      alias Squitter.Decoding.{
        AltitudeReply,
        IdentityReply,
        AllCallReply,
        ShortAcas,
        LongAcas,
        ExtSquitter,
        MilExtSquitter,
        CommDElm,
        CommBAltitudeReply,
        CommBIdentityReply,
        Unknown
      }
    end
  end
end
