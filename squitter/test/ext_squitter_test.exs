defmodule Squitter.ExtSquitterTest do
  use ExUnit.Case, async: true

  alias Squitter.Decoding
  alias Squitter.Decoding.ModeS
  alias Squitter.Test.Frames

  # Reference frames from Junzi Sun, "The 1090MHz Riddle".
  @ident "8D4840D6202CC371C32CE0576098"
  @pos_even "8D40621D58C382D690C8AC2863A7"
  @ground_speed "8D485020994409940838175B284F"

  defp decode(frame), do: Decoding.decode(0, frame)

  # 12-bit altitude field from Gillham bits (Q = 0).
  defp gillham_field(d2, d4, a1, a2, a4, b1, b2, b4, c1, c2, c4) do
    <<n::12>> =
      <<c1::1, a1::1, c2::1, a2::1, c4::1, a4::1, b1::1, 0::1, b2::1, d2::1, b4::1, d4::1>>

    n
  end

  defp position(tc, alt, opts \\ []) do
    Frames.airborne_position_me(tc, alt, 0, 0, 0, opts) |> Frames.es() |> decode()
  end

  describe "reference frames" do
    test "aircraft identification" do
      decoded = decode(@ident)
      assert decoded.crc == :valid
      assert decoded.icao == "4840D6"
      assert decoded.type_msg.callsign == "KLM1023"
    end

    test "barometric altitude with Q = 1" do
      assert decode(@pos_even).type_msg.alt == 38000
    end

    test "ground speed and track" do
      msg = decode(@ground_speed).type_msg
      assert msg.velocity_kt == 159
      assert msg.heading == 183
    end
  end

  test "Gillham altitude matches the reference decoder for every valid code" do
    for n <- 0..2047 do
      <<d2::1, d4::1, a1::1, a2::1, a4::1, b1::1, b2::1, b4::1, c1::1, c2::1, c4::1>> = <<n::11>>

      case Frames.gillham_ref(d2, d4, a1, a2, a4, b1, b2, b4, c1, c2, c4) do
        :invalid -> :ok
        expected -> assert ModeS.gillham_altitude(n) == expected, "code #{n}"
      end
    end
  end

  @tag bug: :gillham_invalid
  test "invalid Gillham codes produce no altitude" do
    for n <- 0..2047 do
      <<d2::1, d4::1, a1::1, a2::1, a4::1, b1::1, b2::1, b4::1, c1::1, c2::1, c4::1>> = <<n::11>>
      alt = gillham_field(d2, d4, a1, a2, a4, b1, b2, b4, c1, c2, c4)
      decoded = position(11, alt).type_msg.alt

      case Frames.gillham_ref(d2, d4, a1, a2, a4, b1, b2, b4, c1, c2, c4) do
        :invalid -> assert decoded == nil, "code #{n} decoded as #{inspect(decoded)}"
        expected -> assert decoded == expected, "code #{n}"
      end
    end
  end

  @tag bug: :velocity_offset
  test "vertical rate is (raw - 1) * 64 fpm" do
    assert decode(@ground_speed).type_msg.vert_rate == -832

    msg = Frames.ground_speed_me(1, 0, 101, 0, 101, vr: {0, 2}) |> Frames.es() |> decode()
    assert msg.type_msg.vert_rate == 64
  end

  @tag bug: :velocity_offset
  test "baro/GNSS altitude difference is (raw - 1) * 25 ft" do
    msg = Frames.ground_speed_me(1, 0, 101, 0, 101, dif: {1, 3}) |> Frames.es() |> decode()
    assert msg.type_msg.geo_delta == -50
  end

  @tag bug: :airspeed
  test "airspeed is raw - 1 kt, times 4 when supersonic, nil when unavailable" do
    assert (Frames.airspeed_me(3, 0, 1, 376) |> Frames.es() |> decode()).type_msg.velocity_kt ==
             375

    assert (Frames.airspeed_me(4, 0, 1, 101) |> Frames.es() |> decode()).type_msg.velocity_kt ==
             400

    assert (Frames.airspeed_me(3, 0, 1, 0) |> Frames.es() |> decode()).type_msg.velocity_kt ==
             nil
  end

  @tag bug: :velocity_unavailable
  test "ground speed with no velocity information yields nil speed and heading" do
    msg = Frames.ground_speed_me(1, 0, 0, 0, 0) |> Frames.es() |> decode()
    assert msg.type_msg.velocity_kt == nil
    assert msg.type_msg.heading == nil
  end

  @tag bug: :velocity_unavailable
  test "ground speed is rounded, not truncated" do
    # 100 kt east, 60 kt north: sqrt(13600) = 116.62
    msg = Frames.ground_speed_me(1, 0, 101, 0, 61) |> Frames.es() |> decode()
    assert msg.type_msg.velocity_kt == 117
  end

  test "ground track just west of north wraps to 0, not 360" do
    # 1 kt west, 150 kt north: track -0.38 deg
    msg = Frames.ground_speed_me(1, 1, 2, 0, 151) |> Frames.es() |> decode()
    assert msg.type_msg.heading == 0
  end

  @tag bug: :gnss_height
  test "GNSS height (TC 20-22) is a plain 12-bit value in meters" do
    # 1000 m = 3280.8 ft. The test assumes the decoder reports feet like baro altitude.
    msg = position(20, 1000)
    assert_in_delta msg.type_msg.alt, 3281, 1
  end

  @tag bug: :utc_time
  test "utc_time reflects the T bit" do
    assert position(11, 0, t: 0).type_msg.utc_time == false
    assert position(11, 0, t: 1).type_msg.utc_time == true
  end

  @tag bug: :nic_gnss
  test "NIC is assigned for GNSS position type codes" do
    assert position(20, 0).type_msg.nic == 11
    assert position(21, 0).type_msg.nic == 10
    assert position(22, 0).type_msg.nic == 0
  end

  @tag bug: :df18_cf
  test "DF18 management and reserved control fields are not decoded as ADS-B" do
    ident_me = <<4::5, 0::3, 20::6, 5::6, 19::6, 20::6, 49::6, 50::6, 51::6, 52::6>>

    for cf <- [4, 7] do
      decoded = ident_me |> Frames.es(df: 18, ca: cf) |> decode()

      refute match?(%{callsign: _}, decoded.type_msg),
             "CF=#{cf} decoded as aircraft identification: #{inspect(decoded.type_msg)}"
    end
  end
end
