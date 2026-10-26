defmodule Squitter.CRCTest do
  use ExUnit.Case, async: true
  use Bitwise

  alias Squitter.Decoding
  alias Squitter.Decoding.ModeS
  alias Squitter.Test.Frames

  @address 0x4840D6

  defp flip_bit(frame, n) do
    <<pre::bitstring-size(n), b::1, post::bitstring>> = frame
    <<pre::bitstring, bxor(b, 1)::1, post::bitstring>>
  end

  test "checksum matches an independent CRC-24 for random frames" do
    :rand.seed(:exsss, {1, 2, 3})

    for _ <- 1..1000, bits <- [56, 112] do
      frame = :rand.bytes(div(bits, 8))
      assert ModeS.checksum(frame, bits) == Frames.crc(frame)
    end
  end

  test "DF17 CRC is valid when intact and invalid when corrupted" do
    frame = Frames.es(<<0::56>>)
    assert Decoding.decode(0, frame).crc == :valid
    assert Decoding.decode(0, flip_bit(frame, 40)).crc == :invalid
  end

  @tag bug: :ap_crc
  test "corrupted address/parity frames are not reported as valid" do
    for {df, head} <- [
          {0, <<0::5, 0x123456::27>>},
          {4, <<4::5, 0x123456::27>>},
          {5, <<5::5, 0x123456::27>>},
          {16, <<16::5, 0x123456::27, 0xDEADBEEF::56>>}
        ] do
      corrupted = Frames.ap(head, @address) |> flip_bit(20)
      decoded = Decoding.decode(0, corrupted)
      assert decoded.crc != :valid, "DF#{df}: corrupted frame reported #{inspect(decoded.crc)}"
    end
  end

  @tag bug: :ap_crc
  test "intact Comm-B address/parity frames are not reported as invalid" do
    for df <- [20, 21] do
      frame = Frames.ap(<<df::5, 0x123456::27, 0xDEADBEEF::56>>, @address)
      decoded = Decoding.decode(0, frame)
      assert decoded.icao == "4840D6"
      assert decoded.crc != :invalid, "DF#{df}: intact frame reported :invalid"
    end
  end

  test "DF11 with interrogator code 0 is valid, corrupted is invalid" do
    frame = Frames.seal(<<11::5, 5::3, @address::24, 0::24>>)
    assert Decoding.decode(0, frame).crc == :valid
    assert Decoding.decode(0, flip_bit(frame, 12)).crc == :invalid
  end

  @tag bug: :df11_interrogator
  test "DF11 replying to a nonzero interrogator code is not rejected" do
    frame = Frames.seal(<<11::5, 5::3, @address::24, 0::24>>, 11)
    decoded = Decoding.decode(0, frame)
    assert decoded.crc != :invalid
    assert decoded.interrogator == 11
  end

  @tag bug: :df11_interrogator
  test "DF11 with a nonzero interrogator code is unverified until the address is known" do
    frame = Frames.seal(<<11::5, 5::3, @address::24, 0::24>>, 11)
    assert Decoding.decode(0, frame).crc == :unverified
  end

  @tag bug: :nif_bounds
  test "checksum rejects a binary shorter than the requested bit count" do
    assert_raise ArgumentError, fn -> ModeS.checksum(<<0x8D>>, 112) end
  end

  @tag bug: :nif_bounds
  test "checksum rejects bit counts other than 56 and 112" do
    assert_raise ArgumentError, fn -> ModeS.checksum(:binary.copy(<<0>>, 32), 256) end
    assert_raise ArgumentError, fn -> ModeS.checksum(:binary.copy(<<0>>, 14), -8) end
  end

  @tag bug: :df16_partition
  test "icao_address/1 recovers the address from a 112-bit DF16" do
    frame = Frames.ap(<<16::5, 0x123456::27, 0xDEADBEEF::56>>, @address)
    assert ModeS.icao_address(frame) == {:ok, "4840D6"}
  end
end
