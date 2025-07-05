defmodule SongbasketWeb.BasketLive do
  use SongbasketWeb, :live_view
  alias Songbasket.{Api, PubSub, Flow, Events}

  @data [
    {:basket_record, nil},
    {:basket, nil}
  ]

  def render(assigns) do
    ~H"""
    <div class="container prose" phx-hook="App" id="app">
      <.link navigate={~p"/"} class="btn btn-primary">
        <Heroicons.folder mini class="size-4" /> Go back
      </.link>

      <button class="btn btn-primary" phx-click="delete_selected_basket">
        <Heroicons.trash mini class="size-4" /> Delete Basket
      </button>
      Basket
      <%= if @basket_record do %>
        <%= @basket_record.path %>
      <% else %>
        No basket selected
      <% end %>

      <%= if @basket do %>
        <div class="grid grid-cols-2 gap-4 mt-4">
          <%= for playlist <- @basket.playlists do %>
            <!--
            <.link navigate={~p"/playlist/#{playlist.id}"} class="btn btn-primary">
              <%= playlist.name %>
            </.link>
            -->
            <button class="btn btn-primary" phx-click="open_playlist" phx-value-id={playlist.id}>
              <%= playlist.name %>
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    Phoenix.PubSub.subscribe(PubSub, Events.default_topic())
    IO.inspect(id, label: "Willl select basket")

    case Flow.select_basket(id) do
      {:ok, _} ->
        IO.puts("Basket mounted")
        {:ok, socket |> assign(@data)}

      {:error, :not_found} ->
        {:ok, push_navigate(socket, to: ~p"/")}
    end

    # {:ok, _} = Flow.initialize(id)
  end

  def handle_info(:basket_changed, socket) do
    fetch_basket_record(socket)
  end

  def handle_info({:basket_repo_initialized, :loaded}, socket) do
    fetch_basket(socket)
  end

  def handle_info(unknown_event, socket) do
    IO.inspect(unknown_event, label: "Unknown event at BasketLive")
    {:noreply, socket}
  end

  def handle_event("delete_selected_basket", _, socket) do
    {:ok, _} = Flow.delete_basket(socket.assigns.basket_record.id)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("open_playlist", %{"id" => id}, socket) do
    Clipboard.copy(id)
    {:noreply, socket}
  end

  def handle_event(params, uri, socket) do
    IO.inspect({params, uri}, label: :handle)
    {:noreply, socket}
  end

  def fetch_basket_record(socket) do
    {:noreply, assign(socket, basket_record: Flow.get_selected_basket())}
  end

  def fetch_basket(socket) do
    {:noreply,
     socket
     |> assign(basket: Songbasket.Basket.get_basket())}
  end
end
