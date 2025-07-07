defmodule SongbasketWeb.BasketPlaylistLive do
  use SongbasketWeb, :live_view
  require Logger
  alias SongbasketWeb.Utils
  alias Songbasket.{Api, PubSub, Flow, Events, Basket}
  alias Songbasket.Basket.{Playlist}

  @data [
    {:basket_record, nil},
    {:id, nil},
    {:playlist, nil},
    {:update_status, {:ok, :done}}
  ]

  def render(assigns) do
    ~H"""
    <div class="container max-w-[1500px] mx-auto" phx-hook="App" id="app">
      <%= if @playlist do %>
        <div class="prose mb-12">
          <h1>
            <%= @playlist.name %>
          </h1>
          <div>
            <div class="flex gap-1 items-center mb-2">
              <%= case @update_status do %>
                <% {:busy, _} -> %>
                  <Heroicons.arrow_path mini class="size-4 animate-spin" />
                <% _ -> %>
                  Last update: <%= @playlist.last_update %>
              <% end %>
            </div>
          </div>
          <button class="btn btn-primary" phx-click="back">
            <Heroicons.arrow_left mini class="size-4" /> Go back
          </button>
          <button
            class="btn btn-primary"
            phx-click="update"
            disabled={match?({:busy, _}, @update_status)}
          >
            <Heroicons.arrow_path mini class="size-4" /> Update
          </button>
          <button
            class="btn btn-primary"
            phx-click="convert"
            disabled={match?({:busy, _}, @update_status)}
          >
            <Heroicons.musical_note mini class="size-4" /> Convert
          </button>
          <button
            class="btn btn-primary"
            phx-click="download"
            disabled={match?({:busy, _}, @update_status)}
          >
            <Heroicons.arrow_down_tray mini class="size-4" /> Download
          </button>
        </div>
        <div class="grid grid-cols-4 gap-y-6">
          <%= for track <- @playlist.tracks do %>
            <div class="card relative">
              <Img.call src={track.album.images["url"]} alt={track.name} id={track.id} />
              <div class="p-4 text-gray-400">
                <h2 class="card-name text-white text-xl font-bold tracking-widest">
                  <%= track.name %>
                </h2>
                <p class="card-text"><%= track.album.name %></p>
                <div class="flex gap-4">
                  <%= for artist <- track.artists do %>
                    <span class="card-text text-white font-bold"><%= artist.name %></span>
                  <% end %>
                </div>
                <%= case track.conversion do %>
                  <% conversion when not is_nil(conversion) -> %>
                    <p class="card-text text-green-500">
                      Conversion: <%= conversion.youtube_video.title %>
                    </p>
                  <% nil -> %>
                    <p class="card-text">No results</p>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        Loading...
      <% end %>
    </div>
    """
  end

  def mount(%{"id" => basket_id, "playlist_id" => id}, _session, socket) do
    Phoenix.PubSub.subscribe(PubSub, Events.default_topic())

    case Flow.select_basket(basket_id) do
      {:ok, _} ->
        IO.puts("Basket mounted")

        {:ok,
         socket
         |> assign(@data)
         |> assign(:id, id)}

      {:error, :not_found} ->
        {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  def handle_info(:basket_changed, socket) do
    {:noreply,
     socket
     |> assign(:basket_record, Flow.get_selected_basket())
     |> put_playlist()}
  end

  def handle_info(event, socket) do
    Logger.warning("Unknown event #{inspect(event)} on playlist live")
    {:noreply, socket}
  end

  def put_playlist(socket) do
    assign(
      socket,
      :playlist,
      Playlist
      |> Basket.get(socket.assigns.id)
      |> Basket.preload(tracks: [:album, :artists, conversion: [:youtube_video]])
    )
  end

  def handle_event("back", _, socket) do
    {:noreply, Utils.navigate_basket(socket, "/")}
  end

  def handle_event("update", _, socket) do
    playlist = socket.assigns.playlist
    socket = assign(socket, :update_status, {:busy, :loading})

    {:noreply,
     start_async(socket, :update_playlist, fn ->
       Basket.update_playlist_tracks(playlist)
     end)}
  end

  def handle_async(:update_playlist, {:ok, result}, socket) do
    {:noreply,
     socket
     |> assign(:update_status, {:ok, :done})
     |> put_playlist}
  end

  def handle_async(:update_playlist, {:exit, reason}, socket) do
    {:noreply, assign(socket, :update_status, {:error, reason})}
  end

  def handle_event("convert", _, socket) do
    playlist = socket.assigns.playlist
    socket = assign(socket, :update_status, {:busy, :converting})

    {:noreply,
     start_async(socket, :convert_playlist, fn ->
       Basket.convert_playlist(playlist)
     end)}
  end

  def handle_async(:convert_playlist, {:ok, result}, socket) do
    {:noreply,
     socket
     |> assign(:update_status, {:ok, :done})
     |> put_playlist}
  end

  def handle_async(:convert_playlist, {:exit, reason}, socket) do
    {:noreply, assign(socket, :update_status, {:error, reason})}
  end

  def handle_event("download", _, socket) do
    playlist = socket.assigns.playlist
    basket_record = socket.assigns.basket_record
    socket = assign(socket, :update_status, {:busy, :downloading})

    {:noreply,
     start_async(socket, :download_playlist, fn ->
       Basket.download_playlist(playlist, basket_record)
     end)}
  end

  def handle_async(:download_playlist, {:ok, result}, socket) do
    {:noreply,
     socket
     |> assign(:update_status, {:ok, :done})
     |> put_playlist}
  end

  def handle_async(:download_playlist, {:exit, reason}, socket) do
    {:noreply, assign(socket, :update_status, {:error, reason})}
  end

  def handle_event(ev, _, socket) do
    dbg(ev)
    {:noreply, socket}
  end
end
