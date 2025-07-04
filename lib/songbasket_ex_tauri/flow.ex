defmodule SongbasketExTauri.Flow do
  import Ecto.Query, warn: false
  alias SongbasketExTauri.{Repo, PubSub, Events, Auth, Basket}
  alias SongbasketExTauri.Basket.{Playlists}
  alias SongbasketExTauri.Flow.{BasketRecord, Config}

  def add_basket(attrs) do
    {:ok, basket} =
      %BasketRecord{}
      |> BasketRecord.changeset(attrs)
      |> Repo.insert()

    Events.emit(:baskets_changed)

    {:ok, basket}
  end

  def delete_basket(id) do
    {:ok, basket} =
      BasketRecord
      |> Repo.get(id)
      |> Repo.delete()

    Events.emit({:basket_removed, basket.id})
    Events.emit(:basket_changed)
    Events.emit(:baskets_changed)

    {:ok, basket}
  end

  def select_basket(id) when is_binary(id) do
    {int, _} = Integer.parse(id)
    select_basket(int)
  end

  def select_basket(id) when is_integer(id) do
    select_basket(%BasketRecord{id: id})
  end

  def select_basket(nil) do
    select_basket(%BasketRecord{id: nil})
  end

  def select_basket(%BasketRecord{} = basket) do
    IO.inspect(basket)

    record =
      if basket.id != nil do
        Repo.get(BasketRecord, basket.id)
      end

    if record == nil do
      {:error, :not_found}
    else
      get_config()
      |> Config.changeset(%{selected_basket_id: basket.id})
      |> Repo.update()
      |> case do
        {:ok, _} ->
          Events.emit(:basket_changed)
          {:ok, basket}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  def get_selected_basket() do
    config =
      get_config()
      |> Repo.preload(:selected_basket)

    config.selected_basket
  end

  def get_baskets() do
    Repo.all(BasketRecord)
  end

  def get_config() do
    case Repo.get(Config, 0) |> IO.inspect() do
      nil -> Repo.insert!(%Config{id: 0, selected_basket: nil})
      config -> config
    end
  end

  def on_open_url(url) do
    IO.inspect(url, label: "Opened with url")

    {:ok, response} =
      Auth.retrieve_token()
      |> IO.inspect(label: :token)

    Events.emit({:auth_success, response})
  end

  def download_playlist(playlist_id) do
    playlist =
      Playlists
      |> Basket.get!(playlist_id)
      |> Basket.preload(:tracks)
      |> Map.get(:tracks)
      |> dbg
  end
end
