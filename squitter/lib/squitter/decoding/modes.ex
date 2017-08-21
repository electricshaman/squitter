defmodule Squitter.Decoding.ModeS do
  require Logger
  use Bitwise, only_operators: true
  import Squitter.Decoding.Utils

  @on_load :load_nif
  @app     Mix.Project.config[:app]
  @compile {:autoload, false}

  def load_nif do
    so_path = Path.join(:code.priv_dir(@app), "modes")
    case :erlang.load_nif(so_path, 0) do
      :ok -> :ok
      {:error, {_reason, msg}} ->
        Logger.warn("Unable to load ModeS NIF: #{to_string(msg)}")
    end
  end

  def checksum(_msg, _bits) do
    raise "NIF checksum/2 not implemented"
  end

  def gillham_altitude(_coded) do
    raise "NIF gillham_altitude/1 not implemented"
  end

  def icao_address(<<df :: 5, _rest :: bits>> = msg, checksum) when df in [0, 4, 5, 16, 20, 21, 24] do
    parity = binary_part(msg, byte_size(msg), -3)
    <<check_bytes :: 3-bytes>> = <<checksum :: 24>>

    address =
      Enum.zip(btol(check_bytes), btol(parity))
      |> Enum.map(fn({c, p}) -> c ^^^ p end)
      |> to_hex_string

    {:ok, address}
  end

  def icao_address(<<df :: 5, _ :: 3, icao :: 3-bytes, _rest :: binary>>, _checksum) when df in [11, 17, 18] do
    {:ok, to_hex_string(icao)}
  end

  def icao_address(_msg, _checksum) do
    :error
  end

  def icao_address(<<df :: 5, _rest :: bits>> = msg) when df in [0, 4, 5, 16] do
    checksum = checksum(msg, 56)
    icao_address(msg, checksum)
  end

  def icao_address(<<df :: 5, _rest :: bits>> = msg) when df in [20, 21, 24] do
    checksum = checksum(msg, 112)
    icao_address(msg, checksum)
  end

  def icao_address(<<df :: 5, _rest :: bits>> = msg) when df in [11, 17, 18] do
    icao_address(msg, nil)
  end

  def icao_address(_other) do
    :error
  end

  def parity(pi, address) do
    address_bytes = hex_to_bin(address)
    <<pi_bytes :: 3-bytes>> = <<pi :: 24-unsigned>>
    <<parity :: 24-unsigned>> =
      Enum.zip(btol(address_bytes), btol(pi_bytes))
      |> Enum.map(fn({a, p}) -> a ^^^ p end)
      |> ltob()
    parity
  end
end
