defmodule SquitterCPRTests do
  use ExUnit.Case
  alias Squitter.Decoding.CPR

  @global_airborne_cases [{80536, 9432, 61720, 9192, 51.686646, 0.700156, 51.686763, 0.701294},
                          {80534, 9413, 61714, 9144, 51.686554, 0.698745, 51.686484, 0.697632}]

  test "decodes global position correctly for even messages" do
    for {even_cprlat, even_cprlon, odd_cprlat, odd_cprlon, even_lat, even_lon, _, _} <- @global_airborne_cases do
      {:ok, [lat, lon]} = CPR.airborne_position(even_cprlat, even_cprlon, odd_cprlat, odd_cprlon, false)

      assert abs(lat - even_lat) < 1.0e-6
      assert abs(lon - even_lon) < 1.0e-6
    end
  end

  test "decodes global position correctly for odd messages" do
    for {even_cprlat, even_cprlon, odd_cprlat, odd_cprlon, _, _, odd_lat, odd_lon} <- @global_airborne_cases do
      {:ok, [lat, lon]} = CPR.airborne_position(even_cprlat, even_cprlon, odd_cprlat, odd_cprlon, true)

      assert abs(lat - odd_lat) < 1.0e-6
      assert abs(lon - odd_lon) < 1.0e-6
    end
  end
end
