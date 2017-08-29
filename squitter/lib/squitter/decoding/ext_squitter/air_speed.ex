defmodule Squitter.Decoding.ExtSquitter.AirSpeed do
  defstruct [
    :intent_change,
    :nac,
    :vert_rate,
    :vert_rate_src,
    :velocity_kt,
    :airspeed_type,
    :heading,
    :baro_alt_diff,
    :supersonic
  ]
end
