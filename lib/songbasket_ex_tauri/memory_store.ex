defmodule SongbasketExTauri.MemoryStore do
  use GenServer

  @table_name :songbasket_kv_store

  # Client API
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def put(key, value), do: GenServer.cast(__MODULE__, {:put, key, value})
  def get(key), do: GenServer.call(__MODULE__, {:get, key})
  def delete(key), do: GenServer.cast(__MODULE__, {:delete, key})

  # Server callbacks
  def init(_) do
    :ets.new(@table_name, [:set, :public, :named_table])
    {:ok, %{}}
  end

  def handle_cast({:put, key, value}, state) do
    :ets.insert(@table_name, {key, value})
    {:noreply, state}
  end

  def handle_cast({:delete, key}, state) do
    :ets.delete(@table_name, key)
    {:noreply, state}
  end

  def handle_call({:get, key}, _from, state) do
    result =
      case :ets.lookup(@table_name, key) do
        [{^key, value}] -> {:ok, value}
        [] -> {:error, :not_found}
      end

    {:reply, result, state}
  end
end
