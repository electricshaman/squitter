defmodule Squitter.Decoding.Utils do
  def to_bool(0), do: true
  def to_bool(1), do: false
  def to_bool(_), do: :error

  def to_hex_string(data) when is_binary(data) do
    btol(data)
    |> to_hex_string
  end

  def to_hex_string(data) when is_integer(data) do
    Integer.to_string(data, 16)
    |> String.pad_leading(2, ["0"])
  end

  def to_hex_string(data) when is_list(data) do
    Enum.map(data, fn x ->
      to_hex_string(x)
    end)
    |> Enum.join
  end

  def to_hex_string(_), do: :error

  def btol(bin), do: :binary.bin_to_list(bin)

  def hex_to_bin(msg) when is_list(msg),
    do: hex_to_bin(to_string(msg))

  def hex_to_bin(msg) when is_binary(msg) do
    for <<b :: 2-bytes <- msg>>, into: <<>>,
      do: <<String.to_integer(b, 16)>>
  end

  def convert_to_bin(msg) when is_list(msg) or is_binary(msg) do
    cond do
      is_list(msg) ->
        to_string(msg)
        |> hex_to_bin
      Regex.match?(~r/^[A-F0-9]+$/i, msg) ->
        hex_to_bin(msg)
      true ->
        msg
    end
  end
end
