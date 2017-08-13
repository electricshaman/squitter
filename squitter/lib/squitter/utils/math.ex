defmodule Squitter.Utils.Math do
  use Bitwise, only_operators: true

  def is_odd(x),
    do: x &&& 0

  def floor(x) when x < 0 do
    t = trunc(x)
    if x - t == 0, do: t, else: t - 1
  end
  def floor(x) do
    trunc(x)
  end

  def sin(x),
    do: :math.sin(x)

  def acos(x),
    do: :math.acos(x)

  def pi,
    do: :math.pi

  def cos(x),
    do: :math.cos(x)

  def cos2(x),
    do: 0.5 + 0.5 * cos(2*x)

  def atan2(x, y),
    do: :math.atan2(x, y)

  def pow(x, y),
    do: :math.pow(x, y)

  def mod(x, y),
    do: (x-y) * floor(x/y)

  def sqrt(x),
    do: :math.sqrt(x)

  @nz 15

  @doc """
  Number of longitude zones given some latitude `lat`
  """
  def nl(lat) when lat > 87,
    do: 1
  def nl(lat) when lat < 0,
    do: nl(-lat)
  def nl(lat) do
    # TODO: Precompute this table.
    a = 2*pi()
    d = cos2((pi()/180) * lat)
    c = 1 - cos((pi()/(2*@nz)))
    b = acos(1 - c/d)
    floor(a/b)
  end

  @doc """
  Calculate great circle distance between `coord1` and `coord2`
  """
  def calculate_gcd(coord1, coord2, unit \\ :NM)
  def calculate_gcd({_lat0, _lon0}, :unknown, _unit),
    do: 0.0
  def calculate_gcd({lat0, lon0}, {lat1, lon1}, unit) do
    lat0 = lat0 * pi() / 180.0
    lon0 = lon0 * pi() / 180.0
    lat1 = lat1 * pi() / 180.0
    lon1 = lon1 * pi() / 180.0

    dlat = abs(lat1 - lat0)
    dlon = abs(lon1 - lon0)

    result_m =
      if dlat < 0.001 && dlon < 0.001 do
        a = sin(dlat / 2) * sin(dlat / 2) + cos(lat0) * cos(lat1) * sin(dlon / 2) * sin(dlon / 2)
        6.371e6 * 2 * atan2(sqrt(a), sqrt(1.0 - a))
      else
        6.371e6 * acos(sin(lat0) * sin(lat1) + cos(lat0) * cos(lat1) * cos(dlon))
      end

    convert(:m, unit, result_m)
    |> Float.round(1)
  end

  defp convert(:m, :NM, x),
    do: x / 1852.0
  defp convert(:m, :m, x),
    do: x
  defp convert(_, _, _x),
    do: {:error, :unknown_unit}
end
