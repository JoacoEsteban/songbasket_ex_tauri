defmodule Songbasket.BasketManager do
  use GenServer
  alias Songbasket.{Basket, Events, PubSub, Flow}
  @db_name Application.compile_env!(:songbasket, :basket_db_name)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # raise "Basket initialization error"
    :ok = Phoenix.PubSub.subscribe(PubSub, Events.default_topic())
    {:ok, %{}}
  end

  def handle_info(:basket_changed, state) do
    basket_record =
      Flow.get_selected_basket()
      |> IO.inspect(label: :basket_changed_to)

    path =
      basket_record
      |> case do
        nil -> nil
        basket -> basket.path
      end
      |> case do
        nil -> nil
        path -> Path.join(path, @db_name)
      end

    Basket.switch_db(path, migrate: true)
    Basket.maybe_initialize(basket_record)

    Events.emit(
      {:basket_repo_initialized,
       case path do
         nil -> :unloaded
         _ -> :loaded
       end}
    )

    {:noreply, state}
  end

  def handle_info(message, state) do
    IO.inspect({:received, message})
    {:noreply, state}
  end
end
