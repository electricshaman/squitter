defmodule Squitter.Enum do
  defmacro __using__(list) do
    generate(list)
  end

  def generate(list) do
    quote bind_quoted: [list: list] do
      @list list
      @keys Keyword.keys(list)

      def list do
        @list
      end

      for {k, v} <- @list do
        def unquote(k)() do
          unquote(v)
        end
      end

      def encode!(key) do
        {:ok, value} = encode(key)
        value
      end

      def encode(key) when key in @keys do
        {:ok, apply(__MODULE__, key, [])}
      end

      def encode(_key) do
        {:error, :invalid_key}
      end

      def decode!(value) do
        {:ok, key} = decode(value)
        key
      end

      def decode(value) do
        case Enum.find(@list, fn {_k, v} -> v == value end) do
          {k, _v} -> {:ok, k}
          _ -> {:error, :no_key}
        end
      end

      def maybe_decode(value) do
        case apply(__MODULE__, :decode, [value]) do
          {:ok, decoded} -> decoded
          {:error, :no_key} -> value
        end
      end
    end
  end
end
