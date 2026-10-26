defmodule Squitter.DownlinkFormatTest do
  use ExUnit.Case, async: true

  alias Squitter.Decoding
  alias Squitter.Decoding.CommDElm
  alias Squitter.Test.Frames

  @address 0x4840D6

  @tag bug: :df19
  test "112-bit DF19 with AF = 0 decodes its address" do
    frame = Frames.seal(<<19::5, 0::3, @address::24, 0::56, 0::24>>)
    assert %{icao: "4840D6"} = Decoding.decode(0, frame)
  end

  @tag bug: :df19
  test "malformed 56-bit DF19 and DF22 frames do not raise" do
    for df <- [19, 22] do
      Decoding.decode(0, <<df::5, 0::51>>)
    end
  end

  @tag bug: :df24
  test "any frame starting with bits 11 is Comm-D (DF24)" do
    for first5 <- 24..31 do
      frame = Frames.ap(<<first5::5, 0::83>>, @address)
      decoded = Decoding.decode(0, frame)

      assert match?(%CommDElm{icao: "4840D6"}, decoded),
             "first 5 bits #{first5}: #{inspect(decoded)}"
    end
  end
end
