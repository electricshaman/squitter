defmodule Squitter.Decoding.ExtSquitter.TypeCode do
  def decode(code) do
    cond do
      code == 0      -> :no_position_info
      code in 1..4   -> {:aircraft_id, code}
      code in 5..8   -> {:surface_pos, code}
      code in 9..18  -> {:airborne_pos_baro_alt, code}
      code == 19     -> :air_velocity
      code in 20..22 -> {:airborne_pos_gnss_height, code}
      code == 23     -> :test_message
      code == 24     -> :surface_sys_status
      code in 25..26 -> {:reserved, code}
      code == 27     -> :trajectory_change
      code == 28     -> :aircraft_status
      code == 29     -> :target_state_status
      code == 30     -> {:reserved, 30}
      code == 31     -> :aircraft_op_status
      true           -> {:unknown, code}
    end
  end
end
