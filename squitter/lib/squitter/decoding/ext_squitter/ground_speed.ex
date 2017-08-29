defmodule Squitter.Decoding.ExtSquitter.GroundSpeed do
  defstruct [
    :intent_change,
    :nac,
    :vert_rate_src,
    :vert_rate,
    :velocity_kt,
    :heading,
    :baro_alt_diff,
    :supersonic
  ]
end
