defmodule Squitter.Decoding.ExtSquitter do
  require Logger
  import Squitter.Decoding.Utils
  alias Squitter.StatsTracker
  alias Squitter.Decoding.ModeS
  alias Squitter.Decoding.ExtSquitter.{
    TypeCode,
    Callsign,
    AirbornePosition,
    AircraftCategory,
    GroundSpeed,
    AirSpeed
  }

  @df   [17, 18]
  @head 37

  defstruct [:df, :tc, :ca, :icao, :msg, :pi, :crc, :type_msg, :time]

  def decode(time, <<df :: 5, ca :: 3, _icao :: 3-bytes, data :: 7-bytes, pi :: 24-unsigned>> = msg) when byte_size(msg) == 14 and df in @df do
    checksum = ModeS.checksum(msg, 112)
    {:ok, icao_address} = ModeS.icao_address(msg, checksum)

    <<tc :: 5, _rest :: bits>> = data
    type = TypeCode.decode(tc)

    StatsTracker.count({:df, df, :decoded})

    %__MODULE__{
      time: time,
      df: df,
      tc: type,
      type_msg: decode_type(type, msg),
      ca: ca,
      icao: icao_address,
      msg: msg,
      pi: pi,
      crc: (if checksum == pi, do: :valid, else: :invalid)}
  end

  def decode(time, <<df :: 5, _ :: bits>> = msg) when df in @df do
    StatsTracker.count({:df, df, :decode_failed})

    Logger.warn "Unrecognized ADS-B message (df #{inspect df}: #{inspect msg}"
    %__MODULE__{
      df: df,
      time: time,
      msg: msg}
  end

  @doc """
  Decode the aircraft identification message.
  """
  def decode_type({:aircraft_id, tc}, <<_ :: @head, cat :: 3, cs :: 6-bytes, _ :: binary>>) do
    callsign = (for <<c :: 6 <- cs>>, into: <<>>, do: Callsign.character(c)) |> String.trim

    %{aircraft_cat: AircraftCategory.decode(tc, cat),
      callsign: callsign}
  end

  @doc """
  Decode the airborne position message.
  """
  def decode_type({alt_type, tc}, msg) when alt_type in [:airborne_pos_baro_alt, :airborne_pos_gnss_height] do
    <<_       :: @head,
      ss      :: 2,
      nicsb   :: 1,
      alt_bin :: 12-bits,
      t       :: 1,
      f       :: 1,
      lat_cpr :: 17,
      lon_cpr :: 17,
      _       :: binary>> = msg

    <<alt_a :: 7, alt_q :: 1, alt_b :: 4>> = alt_bin

    alt =
      if alt_q == 1 do
        <<n :: 11>> = <<alt_a :: 7, alt_b :: 4>>
        n * 25 - 1000
      else
        # TODO: Clean this up somehow
        <<c1 :: 1,
          a1 :: 1,
          c2 :: 1,
          a2 :: 1,
          c4 :: 1,
          a4 :: 1,
          b1 :: 1,
          _  :: 1,
          b2 :: 1,
          d2 :: 1,
          b4 :: 1,
          d4 :: 1>> = alt_bin

        <<n :: 11>> = <<d2 :: 1,
                        d4 :: 1,
                        a1 :: 1,
                        a2 :: 1,
                        a4 :: 1,
                        b1 :: 1,
                        b2 :: 1,
                        b4 :: 1,
                        c1 :: 1,
                        c2 :: 1,
                        c4 :: 1>>

        ModeS.gillham_altitude(n)
      end

    %AirbornePosition{
      tc: tc,
      ss: ss,
      nic_sb: nicsb,
      alt: alt,
      alt_type: alt_type,
      utc_time: to_bool(t),
      flag: f,
      lat_cpr: lat_cpr,
      lon_cpr: lon_cpr}
    |> assign_nic
  end

  @doc """
  Decode the airborne velocity message (ground speed)

  | MSG Bits | DATA Bits | Len | Abbr   | Content                    |
  |----------|-----------|-----|--------|----------------------------|
  | 33-37    | 1-5       | 5   | TC     | Type code                  |
  | 38-40    | 6-8       | 3   | ST     | Subtype                    |
  | 41       | 9         | 1   | IC     | Intent change flag         |
  | 42       | 10        | 1   | RESV_A | Reserved-A                 |
  | 43-45    | 11-13     | 3   | NAC    | Velocity uncertainty (NAC) |
  | 46       | 14        | 1   | S_ew   | East-West velocity sign    |
  | 47-56    | 15-24     | 10  | V_ew   | East-West velocity         |
  | 57       | 25        | 1   | S_ns   | North-South velocity sign  |
  | 58-67    | 26-35     | 10  | V_ns   | North-South velocity       |
  | 68       | 36        | 1   | VrSrc  | Vertical rate source       |
  | 69       | 37        | 1   | S_vr   | Vertical rate sign         |
  | 70-78    | 38-46     | 9   | Vr     | Vertical rate              |
  | 79-80    | 47-48     | 2   | RESV_B | Reserved-B                 |
  | 81       | 49        | 1   | S_Dif  | Diff from baro alt, sign   |
  | 82-88    | 50-66     | 7   | Dif    | Diff from baro alt         |

  Source: http://adsb-decode-guide.readthedocs.io/en/latest/content/airborne-velocity.html
  """
  def decode_type(:air_velocity, <<_ :: 37, st :: 3, body :: binary>>) when st in [1, 2] do
    <<ic      :: 1,
      _resv_a :: 1,
      nac     :: 3,
      s_ew    :: 1,
      v_ew    :: 10,
      s_ns    :: 1,
      v_ns    :: 10,
      vrsrc   :: 1,
      s_vr    :: 1,
      vr      :: 9,
      _resv_b :: 2,
      s_dif  :: 1,
      dif     :: 7,
      _       :: binary>> = body

    {velocity, heading} = calculate_vector(s_ew, s_ns, v_ew, v_ns)

    %GroundSpeed{
      intent_change: ic == 1,
      nac: nac,
      heading: heading,
      velocity_kt: velocity,
      vert_rate_src: vert_rate_source(vrsrc),
      vert_rate: vert_rate(vr, s_vr),
      geo_delta: geo_delta(dif, s_dif),
      supersonic: st == 2}
  end

  @doc """
  Decode the airborne velocity message (air speed)

  | MSG Bits | DATA Bits | Len | Abbr   | Content                        |
  |----------|-----------|-----|--------|--------------------------------|
  | 33-37    | 1-5       | 5   | TC     | Type code                      |
  | 38-40    | 6-8       | 3   | ST     | Subtype                        |
  | 41       | 9         | 1   | IC     | Intent change flag             |
  | 42       | 10        | 1   | RESV_A | Reserved-A                     |
  | 43-45    | 11-13     | 3   | NAC    | Velocity uncertainty (NAC)     |
  | 46       | 14        | 1   | S_hdg  | Heading status                 |
  | 47-56    | 15-24     | 10  | Hdg    | Heading (proportion)           |
  | 57       | 25        | 1   | AS-t   | Airspeed Type                  |
  | 58-67    | 26-35     | 10  | AS     | Airspeed                       |
  | 68       | 36        | 1   | VrSrc  | Vertical rate source           |
  | 69       | 37        | 1   | S_vr   | Vertical rate sign             |
  | 70-78    | 38-46     | 9   | Vr     | Vertical rate                  |
  | 79-80    | 47-48     | 2   | RESV_B | Reserved-B                     |
  | 81       | 49        | 1   | S_Dif  | Difference from baro alt, sign |
  | 82-88    | 50-66     | 7   | Dif    | Difference from baro alt       |

  Source: http://adsb-decode-guide.readthedocs.io/en/latest/content/airborne-velocity.html
  """
  def decode_type(:air_velocity, <<_ :: 37, st :: 3, body :: binary>>) when st in [3, 4] do
    <<ic      :: 1,
      _resv_a :: 1,
      nac     :: 3,
      s_hdg   :: 1,
      hdg     :: 10,
      as_t    :: 1,
      as      :: 10,
      vrsrc   :: 1,
      s_vr    :: 1,
      vr      :: 9,
      _resv_b :: 2,
      s_dif  :: 1,
      dif     :: 7,
      _       :: binary>> = body

    heading = if s_hdg == 1 do
      trunc(:erlang.float(hdg) / 1024.0 * 360.0)
    else
      nil
    end

    %AirSpeed{
      intent_change: ic == 1,
      nac: nac,
      heading: heading,
      velocity_kt: as,
      airspeed_type: (if as_t == 1, do: :true, else: :indicated),
      vert_rate: vert_rate(vr, s_vr),
      vert_rate_src: vert_rate_source(vrsrc),
      geo_delta: geo_delta(dif, s_dif),
      supersonic: st == 4}
  end

  def decode_type(_type, _msg) do
    #Logger.debug "Missed parsing #{inspect type}: #{inspect msg}"
    %{}
  end

  @doc """
  Decode velocity and heading.
  """
  def calculate_vector(sign_ew, sign_ns, v_ew, v_ns) do
    import :math

    v_we = if sign_ew == 1 do
      -1 * (v_ew - 1)
    else
      v_ew - 1
    end

    v_sn = if sign_ns == 1 do
      -1 * (v_ns - 1)
    else
      v_ns - 1
    end

    v = sqrt(pow(v_we, 2) + pow(v_sn, 2))
    h = atan2(v_we, v_sn) * (360/(2 * pi()))

    h = if h < 0, do: h + 360, else: h

    {trunc(v), trunc(h)}
  end

  @doc """
  Decode vertical rate.
  """
  def vert_rate(0, _sign),
    do: nil
  def vert_rate(1, _sign),
    do: 0
  def vert_rate(raw_vr, sign),
    do: vr_dir(raw_vr * 64, sign)

  @doc """
  Apply the sign to the provided vertical rate.
  """
  def vr_dir(vr, sign),
    do: if sign == 1, do: -vr, else: vr

  @doc """
  Decode vertical rate source.
  """
  def vert_rate_source(vrsrc),
    do: if vrsrc == 0, do: :geo, else: :baro

  @doc """
  Decode the Navigational Integrity Category (NIC)

  | TC | SBnic                    | NIC | Rc                 |
  |----|--------------------------|-----|--------------------|
  | 9  | 0                        | 11  | < 7.5 m            |
  | 10 | 0                        | 10  | < 25 m             |
  | 11 | 1                        | 9   | < 74 m             |
  | 11 | 0                        | 8   | < 0.1 NM (185 m)   |
  | 12 | 0                        | 7   | < 0.2 NM (370 m)   |
  | 13 | 1 (NIC Supplement-A = 0) | 6   | < 0.3 NM (556 m)   |
  | 13 | 0                        | 6   | < 0.5 NM (925 m)   |
  | 13 | 1 (NIC Supplement-A = 1) | 6   | < 0.6 NM (1111 m)  |
  | 14 | 0                        | 5   | < 1.0 NM (1852 m)  |
  | 15 | 0                        | 4   | < 2 NM (3704 m)    |
  | 16 | 1                        | 3   | < 4 NM (7408 m)    |
  | 16 | 0                        | 2   | < 8 NM (14.8 km)   |
  | 17 | 0                        | 1   | < 20 NM (37.0 km)  |
  | 18 | 0                        | 0   | > 20 NM or Unknown |

  Source: https://adsb-decode-guide.readthedocs.io/en/latest/content/nicnac.html
  """
  def assign_nic(%{tc: tc, nic_sa: nicsa, nic_sb: nicsb} = pos) do
    {nic, rc} =
      cond do
        tc == 9 && nicsb == 0 ->
          {11, %{limit: 7.5, unit: :m}}
        tc == 10 && nicsb == 0 ->
          {10, %{limit: 25, unit: :m}}
        tc == 11 && nicsb == 1 ->
          {9, %{limit: 74, unit: :m}}
        tc == 11 && nicsb == 0 ->
          {8, %{limit: 0.1, unit: :NM}}
        tc == 12 && nicsb == 0 ->
          {7, %{limit: 0.2, unit: :NM}}
        tc == 13 && nicsb == 1 && nicsa == 0 ->
          {6, %{limit: 0.3, unit: :NM}}
        tc == 13 && nicsb == 0 ->
          {6, %{limit: 0.5, unit: :NM}}
        tc == 13 && nicsb == 1 && nicsa == 1 ->
          {6, %{limit: 0.6, unit: :NM}}
        tc == 14 && nicsb == 0 ->
          {5, %{limit: 1.0, unit: :NM}}
        tc == 15 && nicsb == 0 ->
          {4, %{limit: 2, unit: :NM}}
        tc == 16 && nicsb == 1 ->
          {3, %{limit: 4, unit: :NM}}
        tc == 16 && nicsb == 0 ->
          {2, %{limit: 8, unit: :NM}}
        tc == 17 && nicsb == 0 ->
          {1, %{limit: 20, unit: :NM}}
        tc == 18 && nicsb == 0 ->
          {0, %{limit: :unknown}}
        true ->
          {:unknown, :unknown}
      end
    %{pos | nic: nic, rc: rc}
  end

  @doc """
  Decode the delta between barometric altitude and geometric altitude.
  If the result is positive, geometric altitude is above barometric altitude.
  If the result is negative, geometric altitude is below barometric altitude.
  If the result is nil, no delta information is available.
  """
  def geo_delta(0, _sign),
    do: nil
  def geo_delta(1, _sign),
    do: 0
  def geo_delta(raw_delta, sign),
    do: geo_delta_dir(raw_delta * 25, sign)

  @doc """
  Apply the sign to the provided geo delta.
  """
  def geo_delta_dir(geo_delta, sign),
    do: if sign == 1, do: -geo_delta, else: geo_delta
end
