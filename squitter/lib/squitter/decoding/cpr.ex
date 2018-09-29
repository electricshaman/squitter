defmodule Squitter.Decoding.CPR do
  import :math

  # Mostly taken from https://github.com/mutability/dump1090/blob/master/cpr.c

  @cpr_max :math.pow(2, 17)

  def airborne_position(even_cprlat, even_cprlon, odd_cprlat, odd_cprlon, fflag?) do
    air_dlat0 = 360.0 / 60.0
    air_dlat1 = 360.0 / 59.0
    lat0 = even_cprlat
    lat1 = odd_cprlat
    lon0 = even_cprlon
    lon1 = odd_cprlon

    j = trunc(floor((59 * lat0 - 60 * lat1) / @cpr_max + 0.5))

    rlat0 =
      case air_dlat0 * (cpr_mod(j, 60) + lat0 / @cpr_max) do
        result when result >= 270 ->
          result - 360

        result ->
          result
      end

    rlat1 =
      case air_dlat1 * (cpr_mod(j, 59) + lat1 / @cpr_max) do
        result when result >= 270 ->
          result - 360

        result ->
          result
      end

    with :ok <- check_rlat_range(rlat0, rlat1),
         :ok <- check_rlat_zones(rlat0, rlat1) do
      {lat, lon} =
        if fflag? do
          # Odd packet
          ni = n(rlat1, fflag?)
          m = trunc(floor((lon0 * (nl(rlat1) - 1) - lon1 * nl(rlat1)) / @cpr_max + 0.5))
          rlon = dlon(rlat1, fflag?, false) * (cpr_mod(m, ni) + lon1 / @cpr_max)
          rlat = rlat1
          {rlat, rlon}
        else
          # Even packet
          ni = n(rlat0, fflag?)
          m = trunc(floor((lon0 * (nl(rlat0) - 1) - lon1 * nl(rlat0)) / @cpr_max + 0.5))
          rlon = dlon(rlat0, fflag?, false) * (cpr_mod(m, ni) + lon0 / @cpr_max)
          rlat = rlat0
          {rlat, rlon}
        end

      # Renormalize longitude to -180..180
      lon = lon - floor((lon + 180) / 360) * 360

      {:ok, [Float.round(lat, 6), Float.round(lon, 6)]}
    end
  end

  # Private

  defp check_rlat_range(rlat0, rlat1) do
    if rlat0 < -90 || rlat0 > 90 || rlat1 < -90 || rlat1 > 90,
      do: {:error, :lat_range},
      else: :ok
  end

  defp check_rlat_zones(rlat0, rlat1) do
    if nl(rlat0) == nl(rlat1),
      do: :ok,
      else: {:error, :diff_lat_zones}
  end

  defp cpr_mod(a, b) when is_integer(a) and is_integer(b) do
    res = rem(a, b)
    if res < 0, do: res + b, else: res
  end

  defp cpr_mod(a, b) when is_float(a) and is_float(b) do
    res = fmod(a, b)
    if res < 0.0, do: res + b, else: res
  end

  defp n(lat, fflag?) do
    nl = nl(lat) - if fflag?, do: 1, else: 0
    if nl < 1, do: 1, else: nl
  end

  defp dlon(lat, fflag?, surface?) do
    if(surface?, do: 90, else: 360) / n(lat, fflag?)
  end

  @doc """
  Number of longitude zones for the given latitude `lat`
  """
  def nl(lat) do
    if lat < 0, do: nl(-lat)

    cond do
      lat < 10.47047130 -> 59
      lat < 14.82817437 -> 58
      lat < 18.18626357 -> 57
      lat < 21.02939493 -> 56
      lat < 23.54504487 -> 55
      lat < 25.82924707 -> 54
      lat < 27.93898710 -> 53
      lat < 29.91135686 -> 52
      lat < 31.77209708 -> 51
      lat < 33.53993436 -> 50
      lat < 35.22899598 -> 49
      lat < 36.85025108 -> 48
      lat < 38.41241892 -> 47
      lat < 39.92256684 -> 46
      lat < 41.38651832 -> 45
      lat < 42.80914012 -> 44
      lat < 44.19454951 -> 43
      lat < 45.54626723 -> 42
      lat < 46.86733252 -> 41
      lat < 48.16039128 -> 40
      lat < 49.42776439 -> 39
      lat < 50.67150166 -> 38
      lat < 51.89342469 -> 37
      lat < 53.09516153 -> 36
      lat < 54.27817472 -> 35
      lat < 55.44378444 -> 34
      lat < 56.59318756 -> 33
      lat < 57.72747354 -> 32
      lat < 58.84763776 -> 31
      lat < 59.95459277 -> 30
      lat < 61.04917774 -> 29
      lat < 62.13216659 -> 28
      lat < 63.20427479 -> 27
      lat < 64.26616523 -> 26
      lat < 65.31845310 -> 25
      lat < 66.36171008 -> 24
      lat < 67.39646774 -> 23
      lat < 68.42322022 -> 22
      lat < 69.44242631 -> 21
      lat < 70.45451075 -> 20
      lat < 71.45986473 -> 19
      lat < 72.45884545 -> 18
      lat < 73.45177442 -> 17
      lat < 74.43893416 -> 16
      lat < 75.42056257 -> 15
      lat < 76.39684391 -> 14
      lat < 77.36789461 -> 13
      lat < 78.33374083 -> 12
      lat < 79.29428225 -> 11
      lat < 80.24923213 -> 10
      lat < 81.19801349 -> 9
      lat < 82.13956981 -> 8
      lat < 83.07199445 -> 7
      lat < 83.99173563 -> 6
      lat < 84.89166191 -> 5
      lat < 85.75541621 -> 4
      lat < 86.53536998 -> 3
      lat < 87.00000000 -> 2
      true -> 1
    end
  end
end
