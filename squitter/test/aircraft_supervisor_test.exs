defmodule Squitter.AircraftSupervisorTest do
  # AircraftRegistry is a globally registered process.
  use ExUnit.Case, async: false

  alias Squitter.{AircraftSupervisor, Decoding}
  alias Squitter.Test.Frames

  @address 0x4840D6

  # AircraftSupervisor isn't started, so any attempt to create an aircraft exits the test.
  setup do
    start_supervised!({Registry, keys: :unique, name: Squitter.AircraftRegistry})
    :ok
  end

  defp df4, do: Decoding.decode(0, Frames.ap(<<4::5, 0x123456::27>>, @address))

  @tag bug: :ap_crc
  test "address/parity replies are unverified" do
    assert df4().crc == :unverified
  end

  @tag bug: :ap_crc
  test "unverified messages for an untracked address are dropped" do
    assert AircraftSupervisor.dispatch(df4()) == {:error, :unknown_address}
  end

  @tag bug: :ap_crc
  test "unverified messages reach an aircraft already tracked" do
    {:ok, _} = Registry.register(Squitter.AircraftRegistry, "4840D6", nil)
    msg = df4()

    assert AircraftSupervisor.dispatch(msg) == :ok
    assert_receive {:"$gen_cast", {:dispatch, ^msg}}
  end

  @tag bug: :df11_interrogator
  test "DF11 with a nonzero interrogator code reaches only a tracked aircraft" do
    msg = Decoding.decode(0, Frames.seal(<<11::5, 5::3, @address::24, 0::24>>, 11))
    assert AircraftSupervisor.dispatch(msg) == {:error, :unknown_address}

    {:ok, _} = Registry.register(Squitter.AircraftRegistry, "4840D6", nil)
    assert AircraftSupervisor.dispatch(msg) == :ok
    assert_receive {:"$gen_cast", {:dispatch, ^msg}}
  end

  @tag bug: :ap_crc
  test "messages with an invalid CRC are dropped without creating an aircraft" do
    <<head::bitstring-size(100), b::1, tail::bitstring>> = Frames.es(<<0::56>>)
    corrupted = Decoding.decode(0, <<head::bitstring, 1 - b::1, tail::bitstring>>)

    assert AircraftSupervisor.dispatch(corrupted) == {:error, :invalid_crc}
  end
end
