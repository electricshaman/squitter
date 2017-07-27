defmodule H do
  def lli do
    Logger.configure(level: :info)
  end

  def lld do
    Logger.configure(level: :debug)
  end
end
