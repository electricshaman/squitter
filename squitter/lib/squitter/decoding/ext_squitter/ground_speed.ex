defmodule Squitter.Decoding.ExtSquitter.GroundSpeed do
  defstruct [
    :intent_change,
    :nac,
    :vert_rate_src,
    :vert_rate,
    :velocity_kt,
    :heading,
    :geo_delta,
    :supersonic
  ]
end
