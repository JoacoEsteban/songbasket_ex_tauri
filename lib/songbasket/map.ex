defmodule Songbasket.Map do
  def to_string_map(map) when is_struct(map) do
    map
    |> Map.from_struct()
    # |> struct_to_map()
    |> to_string_map()
  end

  def to_string_map(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      key = if is_atom(k), do: Atom.to_string(k), else: k
      Map.put(acc, key, to_string_map(v))
    end)
  end

  def to_string_map([head | tail]), do: [to_string_map(head) | to_string_map(tail)]
  def to_string_map(value), do: value

  def struct_to_map(struct) do
    struct
    |> Map.delete(:__struct__)
    |> Map.delete(:__meta__)
    |> Map.delete(:associations)
  end
end
