defmodule SongbasketExTauri.Utils do
  defmacro __using__(_opts) do
    quote do
      import SongbasketExTauri.Utils
    end
  end

  defmacro time(do: block) do
    quote do
      {elapsed, result} = :timer.tc(fn -> unquote(block) end)
      IO.puts("console_time: #{elapsed / 1_000} ms")
      result
    end
  end

  def mmss_to_ms(str) do
    [min, sec] = String.split(str, ":") |> Enum.map(&String.to_integer/1)
    (min * 60 + sec) * 1000
  end
end
