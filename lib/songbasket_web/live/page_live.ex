defmodule SongbasketWeb.PageLive do
  use SongbasketWeb, :live_view
  alias Songbasket.{Api, PubSub, Flow, Events}
  alias SongbasketWeb.Components.{Basket, Home, NewBasket}

  def update_basket(socket) do
    socket
    |> assign(selected_basket: Songbasket.Flow.get_selected_basket())
  end

  def update_baskets(socket) do
    socket
    |> assign(baskets: Songbasket.Flow.get_baskets())
  end

  def fetch_basket(socket) do
    socket
    |> assign(basket: Songbasket.Basket.get_basket())
  end

  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(PubSub, Events.default_topic())

    {:ok,
     socket
     |> update_basket()
     |> update_baskets()
     |> assign(
       urls: [],
       playlists: [],
       creating_basket: false,
       selected_basket: nil,
       basket: nil,
       auth_success: nil
     )}
  end

  def handle_info(:basket_changed, socket) do
    {:noreply, update_basket(socket)}
  end

  def handle_info(:baskets_changed, socket) do
    {:noreply, update_baskets(socket)}
  end

  def handle_info({:basket_repo_initialized, :loaded}, socket) do
    {:noreply, fetch_basket(socket)}
  end

  def handle_info({:auth_success, response}, socket) do
    {:noreply,
     socket
     |> assign(auth_success: response)}
  end

  def handle_info(unknown_event, socket) do
    IO.inspect(unknown_event, label: :unknown_event)
    {:noreply, socket}
  end

  def handle_event("quit", _params, socket) do
    :ok = :init.stop()
    {:noreply, socket}
  end

  def handle_event("open_url", %{"url" => nil}, socket) do
    {:noreply, socket}
  end

  def handle_event("open_url", %{"url" => url}, socket) do
    Flow.on_open_url(url)
    {:noreply, assign(socket, urls: [url | socket.assigns.urls])}
  end

  def handle_event("current_open_url", %{"url" => url}, socket) do
    {:noreply, socket}
  end

  def handle_event("unselect_basket", _params, socket) do
    Flow.select_basket(nil)
    {:noreply, socket}
  end

  # def handle_event("select_basket", %{"id" => id}, socket) do
  #   Flow.select_basket(id)
  #   {:noreply, socket}
  # end

  def handle_event("delete_selected_basket", _, socket) do
    {:ok, _} = Flow.delete_basket(socket.assigns.selected_basket.id)
    {:noreply, socket}
  end

  def handle_event("new_basket", _, socket) do
    case socket.assigns.selected_basket do
      nil ->
        {:noreply,
         socket
         |> assign(creating_basket: true)}

      _ ->
        {:noreply, socket}
    end
  end

  # def handle_event("dialog-answer", [nil, detail], socket) do
  #   IO.inspect(detail, label: "dialog-answer_home")
  #   {:noreply, socket}
  # end

  # def handle_event("dialog-answer", [answer, detail], socket) do
  #   IO.inspect({answer, detail}, label: "dialog-answer")
  #   {:noreply, socket}
  # end

  def render(assigns) do
    ~H"""
    <div class="container prose" phx-hook="App" id="app">
      <h1>
        Songbasket
      </h1>

      <%= for basket <- @baskets do %>
        <.link navigate={~p"/baskets/#{basket.id}"} class="btn btn-primary">
          <%= basket.path %>
        </.link>
      <% end %>
      <.link navigate={~p"/new_basket"} class="btn btn-primary">
        New basket
      </.link>
    </div>
    """
  end
end
