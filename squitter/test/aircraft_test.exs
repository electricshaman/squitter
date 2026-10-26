defmodule Squitter.AircraftTest do
  # Site is a globally registered process.
  use ExUnit.Case, async: false

  alias Squitter.{Aircraft, Decoding, Site}

  # Reference pair from Junzi Sun, "The 1090MHz Riddle": decodes to about 52.2572, 3.9194.
  @even "8D40621D58C382D690C8AC2863A7"
  @odd "8D40621D58C386435CC412692AD6"

  defp state(even, odd, latlon) do
    %{
      address: "40621D",
      callsign: "",
      altitude: 38000,
      latlon: latlon,
      distance: 0.0,
      position_history: [],
      last_even_position: even,
      last_odd_position: odd
    }
  end

  defp pos(hex), do: Decoding.decode(0, hex).type_msg

  @tag bug: :cpr_stale_pair
  test "a stale pair keeps the newer frame" do
    # Odd arrives 6 s (in microseconds) after even, past the pairing window.
    odd = {6_000_000, pos(@odd)}
    {:ok, new} = Aircraft.calculate_position(state({0, pos(@even)}, odd, nil))

    assert new.last_even_position == nil
    assert new.last_odd_position == odd

    even = {6_000_000, pos(@even)}
    {:ok, new} = Aircraft.calculate_position(state(even, {0, pos(@odd)}, nil))

    assert new.last_even_position == even
    assert new.last_odd_position == nil
  end

  @tag bug: :position_jump
  test "an implausible jump within site range is rejected" do
    start_supervised!(%{id: Site, start: {Site, :start_link, [[52.0, 4.0], 1000]}})

    # The pair decodes ~135 NM from the previous fix, one second later.
    previous = [50.0, 3.9]
    s = state({0, pos(@even)}, {1_000_000, pos(@odd)}, previous)
    {:ok, new} = Aircraft.calculate_position(s)

    assert new.latlon == previous
  end
end
