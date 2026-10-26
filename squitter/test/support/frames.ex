defmodule Squitter.Test.Frames do
  @moduledoc """
  Builders for Mode S test frames. Everything here is implemented independently
  of the code under test so it can serve as a reference.
  """
  import Bitwise

  @cpr_max 131_072

  @doc """
  Bitwise CRC-24 (generator 0x1FFF409) over all but the last 24 bits of `frame`.
  """
  def crc(frame) do
    data = binary_part(frame, 0, byte_size(frame) - 3)

    for <<b::1 <- data>>, reduce: 0 do
      acc ->
        acc = bxor(acc, b <<< 23)

        if band(acc, 0x800000) != 0,
          do: band(bxor(acc <<< 1, 0xFFF409), 0xFFFFFF),
          else: band(acc <<< 1, 0xFFFFFF)
    end
  end

  @doc """
  Replace the last 24 bits of `frame` with its CRC XOR `overlay`.
  `overlay` is 0 for PI formats, the address for AP formats, or the
  interrogator code for DF11.
  """
  def seal(frame, overlay \\ 0) do
    data = binary_part(frame, 0, byte_size(frame) - 3)
    <<data::binary, bxor(crc(frame), overlay)::24>>
  end

  @doc "A 112-bit extended squitter carrying the 56-bit `me` field."
  def es(me, opts \\ []) do
    df = Keyword.get(opts, :df, 17)
    ca = Keyword.get(opts, :ca, 5)
    address = Keyword.get(opts, :address, 0x4840D6)
    seal(<<df::5, ca::3, address::24, me::bitstring-size(56), 0::24>>)
  end

  @doc "An address/parity frame: `head` is everything before the 24 AP bits."
  def ap(head, address), do: seal(<<head::bitstring, 0::24>>, address)

  @doc """
  Airborne position ME field. `alt` is the raw 12-bit altitude field.
  """
  def airborne_position_me(tc, alt, f, lat_cpr, lon_cpr, opts \\ []) do
    ss = Keyword.get(opts, :ss, 0)
    nic_sb = Keyword.get(opts, :nic_sb, 0)
    t = Keyword.get(opts, :t, 0)
    <<tc::5, ss::2, nic_sb::1, alt::12, t::1, f::1, lat_cpr::17, lon_cpr::17>>
  end

  @doc "Airborne velocity ME field, subtype 1/2 (ground speed). Raw field values."
  def ground_speed_me(sub, s_ew, v_ew, s_ns, v_ns, opts \\ []) do
    {s_vr, vr} = Keyword.get(opts, :vr, {0, 0})
    {s_dif, dif} = Keyword.get(opts, :dif, {0, 0})

    <<19::5, sub::3, 0::1, 0::1, 0::3, s_ew::1, v_ew::10, s_ns::1, v_ns::10, 0::1, s_vr::1, vr::9,
      0::2, s_dif::1, dif::7>>
  end

  @doc "Airborne velocity ME field, subtype 3/4 (airspeed). Raw field values."
  def airspeed_me(sub, hdg, as_t, as) do
    <<19::5, sub::3, 0::1, 0::1, 0::3, 1::1, hdg::10, as_t::1, as::10, 0::1, 0::1, 0::9, 0::2,
      0::1, 0::7>>
  end

  @doc """
  Number of longitude zones, from the closed-form definition in DO-260B.
  """
  def nl(lat) do
    lat = abs(lat)

    cond do
      lat == 0 ->
        59

      lat == 87 ->
        2

      lat > 87 ->
        1

      true ->
        a = 1 - :math.cos(:math.pi() / 30)
        b = :math.pow(:math.cos(:math.pi() / 180 * lat), 2)
        trunc(Float.floor(2 * :math.pi() / :math.acos(1 - a / b)))
    end
  end

  @doc """
  Airborne CPR encoding of `{lat, lon}` for format `i` (0 = even, 1 = odd).
  Returns `{lat_cpr, lon_cpr}`.
  """
  def cpr_encode(lat, lon, i) do
    dlat = 360 / (60 - i)
    yz = Float.floor(@cpr_max * fmod(lat, dlat) / dlat + 0.5)
    rlat = dlat * (yz / @cpr_max + Float.floor(lat / dlat))
    dlon = 360 / max(nl(rlat) - i, 1)
    xz = Float.floor(@cpr_max * fmod(lon, dlon) / dlon + 0.5)
    {rem(trunc(yz), @cpr_max), rem(trunc(xz), @cpr_max)}
  end

  defp fmod(a, b), do: a - b * Float.floor(a / b)

  @doc """
  Reference Gillham (Mode C) decoder, after dump1090's mode_ac.c.
  Returns altitude in feet, or `:invalid`.
  """
  def gillham_ref(d2, d4, a1, a2, a4, b1, b2, b4, c1, c2, c4) do
    one =
      [{c1, 7}, {c2, 3}, {c4, 1}]
      |> Enum.reduce(0, fn {bit, m}, acc -> if bit == 1, do: bxor(acc, m), else: acc end)

    one = if band(one, 5) == 5, do: bxor(one, 2), else: one

    if one > 5 or one == 0 do
      :invalid
    else
      five =
        [{d2, 0xFF}, {d4, 0x7F}, {a1, 0x3F}, {a2, 0x1F}, {a4, 0x0F}, {b1, 7}, {b2, 3}, {b4, 1}]
        |> Enum.reduce(0, fn {bit, m}, acc -> if bit == 1, do: bxor(acc, m), else: acc end)

      one = if band(five, 1) == 1, do: 6 - one, else: one
      (five * 5 + one - 13) * 100
    end
  end
end
