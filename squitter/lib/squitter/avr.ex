defmodule Squitter.AVR do
  @doc """
  Split multiple raw frames up into a list.
  """
  def split_frames(data) do
    Enum.reject(data, fn c -> c == 10 || c == 13 end)
    |> split_frames([], [])
  end

  # 42 is *
  # Is * the meaning of life?
  def split_frames([42|tail], [], frames) do
    split_frames(tail, [], frames)
  end

  def split_frames([42|tail], current, frames) do
    split_frames(tail, [], [to_frame(current)|frames])
  end

  # 59 is ;
  def split_frames([59|tail], current, frames) do
    split_frames(tail, [], [to_frame(current)|frames])
  end

  def split_frames([nibble|tail], current, frames) do
    split_frames(tail, [nibble|current], frames)
  end

  def split_frames([], current, frames),
    do: {Enum.reverse(frames), [42|Enum.reverse(current)]}

  defp to_frame(list) do
    Enum.reverse(list) |> to_string
  end
end
