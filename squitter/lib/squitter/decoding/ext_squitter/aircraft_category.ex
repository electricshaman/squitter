defmodule Squitter.Decoding.ExtSquitter.AircraftCategory do
  @doc """
  Decode the aircraft category.

  | MSG Bits | Category Set |
  |----------|--------------|
  | 33-37    | 1-5          |

  """
  def decode(type_code, category) do
    case type_code do
      1 -> decode_set_d(category)
      2 -> decode_set_c(category)
      3 -> decode_set_b(category)
      4 -> decode_set_a(category)
    end
  end

  defp decode_set_a(category) do
    value = case category do
      0 -> :none
      1 -> :light
      2 -> :small
      3 -> :large
      4 -> :high_vortex
      5 -> :heavy
      6 -> :high_perf
      7 -> :rotorcraft
      _ -> :error
    end
    %{set: :standard, category: value}
  end

  defp decode_set_b(category) do
    value = case category do
      0 -> :none
      1 -> :glider
      2 -> :lighter_than_air
      3 -> :parachutist
      4 -> :ultralight
      5 -> :reserved
      6 -> :uav
      7 -> :space_vehicle
      _ -> :error
    end
    %{set: :non_standard, category: value}
  end

  defp decode_set_c(category) do
    value = case category do
      0 -> :none
      1 -> :emergency_vehicle
      2 -> :service_vehicle
      3 -> :fixed_ground
      4 -> :cluster_obstacle
      5 -> :line_obstacle
      6 -> :reserved
      7 -> :reserved
      _ -> :error
    end
    %{set: :surface, category: value}
  end

  defp decode_set_d(category) do
    value = case category do
      0 -> :na
      _ -> :reserved
    end
    %{set: :reserved, category: value}
  end
end
