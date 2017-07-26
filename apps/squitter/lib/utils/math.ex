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

  def acos(x),
    do: :math.acos(x)

  def pi,
    do: :math.pi

  def cos(x),
    do: :math.cos(x)

  def cos2(x),
    do: 0.5 + 0.5 * cos(2*x)

  def pow(x, y),
    do: :math.pow(x, y)

  def mod(x, y),
    do: (x-y) * floor(x/y)

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
end
