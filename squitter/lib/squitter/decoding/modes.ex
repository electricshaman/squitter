defmodule Squitter.Decoding.ModeS do
  import Bitwise
  import Squitter.Decoding.Utils

  # CRC-24 generator polynomial (0x1FFF409 without the implicit top bit).
  @poly 0xFFF409

  # CRC of each byte value, for a byte-at-a-time CRC.
  @crc_table (for i <- 0..255 do
                Enum.reduce(1..8, i <<< 16, fn _, c ->
                  c = c <<< 1
                  if (c &&& 0x1000000) != 0, do: bxor(c, @poly) &&& 0xFFFFFF, else: c
                end)
              end)
             |> List.to_tuple()

  @doc """
  Mode S CRC-24 over the data bits of a 56 or 112 bit frame (everything before
  the 24 parity bits). Raises `ArgumentError` for any other bit count, or if
  `msg` is shorter than `bits`.
  """
  def checksum(msg, bits)
      when bits in [56, 112] and is_binary(msg) and byte_size(msg) * 8 >= bits do
    msg
    |> binary_part(0, div(bits - 24, 8))
    |> crc(0)
  end

  def checksum(_msg, _bits), do: raise(ArgumentError, "expected a 56 or 112 bit frame")

  defp crc(<<byte, rest::binary>>, acc) do
    index = bxor(acc >>> 16, byte)
    crc(rest, bxor(acc <<< 8 &&& 0xFFFFFF, elem(@crc_table, index)))
  end

  defp crc(<<>>, acc), do: acc

  @doc """
  Altitude in feet from an 11-bit Gillham code ordered D2 D4 A1 A2 A4 B1 B2 B4
  C1 C2 C4. Callers must reject invalid codes first; see
  `Squitter.Decoding.ExtSquitter`.
  """
  def gillham_altitude(coded) when is_integer(coded) do
    # Gray-decode the whole code; the reflected 100 ft part then needs fixing up.
    value = coded |> ungray(8) |> ungray(4) |> ungray(2) |> ungray(1)
    value = value - ((value >>> 4) * 6 + div(rem(value, 16), 5) * 2)
    (value - 13) * 100
  end

  defp ungray(value, shift), do: bxor(value, value >>> shift)

  def icao_address(<<df::5, _rest::bits>> = msg, checksum)
      when df in [0, 4, 5, 16, 20, 21] or df >= 24 do
    parity = binary_part(msg, byte_size(msg), -3)
    <<check_bytes::3-bytes>> = <<checksum::24>>

    address =
      Enum.zip(btol(check_bytes), btol(parity))
      |> Enum.map(fn {c, p} -> bxor(c, p) end)
      |> to_hex_string

    {:ok, address}
  end

  # DF18 CF 1 and 5 carry non-ICAO addresses. Prefix them (readsb's convention)
  # so they can't collide with a real aircraft's address.
  def icao_address(<<18::5, cf::3, address::3-bytes, _rest::binary>>, _checksum)
      when cf in [1, 5] do
    {:ok, "~" <> to_hex_string(address)}
  end

  def icao_address(<<df::5, _::3, icao::3-bytes, _rest::binary>>, _checksum)
      when df in [11, 17, 18] do
    {:ok, to_hex_string(icao)}
  end

  def icao_address(<<19::5, 0::3, icao::3-bytes, _rest::binary>>, _checksum) do
    {:ok, to_hex_string(icao)}
  end

  def icao_address(_msg, _checksum) do
    :error
  end

  def icao_address(<<df::5, _rest::bits>> = msg) when df in [0, 4, 5] do
    checksum = checksum(msg, 56)
    icao_address(msg, checksum)
  end

  def icao_address(<<df::5, _rest::bits>> = msg) when df in [16, 20, 21] or df >= 24 do
    checksum = checksum(msg, 112)
    icao_address(msg, checksum)
  end

  def icao_address(<<df::5, _rest::bits>> = msg) when df in [11, 17, 18, 19] do
    icao_address(msg, nil)
  end

  def icao_address(_other) do
    :error
  end

  def parity(pi, address) do
    address_bytes = hex_to_bin(address)
    <<pi_bytes::3-bytes>> = <<pi::24-unsigned>>

    <<parity::24-unsigned>> =
      Enum.zip(btol(address_bytes), btol(pi_bytes))
      |> Enum.map(fn {a, p} -> bxor(a, p) end)
      |> ltob()

    parity
  end
end
