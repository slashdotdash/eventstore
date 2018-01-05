defmodule EventStore.Wait do
  def until(fun), do: until(1_000, fun)

  def until(0, fun), do: fun.()

  def until(timeout, fun) do
    try do
      fun.()
    rescue
      ExUnit.AssertionError ->
        :timer.sleep(10)
        until(max(0, timeout - 10), fun)
    end
  end
end
