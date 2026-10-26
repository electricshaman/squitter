defmodule SquitterCPRTests do
  use ExUnit.Case
  alias Squitter.Decoding.CPR
  alias Squitter.Test.Frames

  @global_airborne_cases [
    {80536, 9432, 61720, 9192, 51.686646, 0.700156, 51.686763, 0.701294},
    {80534, 9413, 61714, 9144, 51.686554, 0.698745, 51.686484, 0.697632}
  ]

  test "decodes global position correctly for even messages" do
    for {even_cprlat, even_cprlon, odd_cprlat, odd_cprlon, even_lat, even_lon, _, _} <-
          @global_airborne_cases do
      {:ok, [lat, lon]} =
        CPR.airborne_position(even_cprlat, even_cprlon, odd_cprlat, odd_cprlon, false)

      assert abs(lat - even_lat) < 1.0e-6
      assert abs(lon - even_lon) < 1.0e-6
    end
  end

  test "decodes global position correctly for odd messages" do
    for {even_cprlat, even_cprlon, odd_cprlat, odd_cprlon, _, _, odd_lat, odd_lon} <-
          @global_airborne_cases do
      {:ok, [lat, lon]} =
        CPR.airborne_position(even_cprlat, even_cprlon, odd_cprlat, odd_cprlon, true)

      assert abs(lat - odd_lat) < 1.0e-6
      assert abs(lon - odd_lon) < 1.0e-6
    end
  end

  # Latitudes chosen to stay clear of NL zone boundaries.
  @lats Enum.map(0..230, &(&1 * 0.37 + 0.05))

  test "nl matches the closed-form definition for northern latitudes" do
    for lat <- @lats, do: assert(CPR.nl(lat) == Frames.nl(lat), "lat #{lat}")
  end

  @tag bug: :southern_cpr
  test "nl matches the closed-form definition for southern latitudes" do
    for lat <- @lats, do: assert(CPR.nl(-lat) == Frames.nl(-lat), "lat #{-lat}")
  end

  defp round_trip(lat, lon) do
    {even_lat, even_lon} = Frames.cpr_encode(lat, lon, 0)
    {odd_lat, odd_lon} = Frames.cpr_encode(lat, lon, 1)

    for fflag? <- [false, true] do
      {:ok, [dlat, dlon]} = CPR.airborne_position(even_lat, even_lon, odd_lat, odd_lon, fflag?)
      assert_in_delta dlat, lat, 1.0e-4
      assert_in_delta dlon, lon, 1.0e-4
    end
  end

  test "round-trips northern positions" do
    round_trip(40.795, -98.915)
    round_trip(52.2572, 3.9194)
  end

  @tag bug: :southern_cpr
  test "round-trips southern positions" do
    round_trip(-33.9461, 151.1772)
    round_trip(-54.8019, -68.3030)
  end
end
