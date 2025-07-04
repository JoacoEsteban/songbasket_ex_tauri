defmodule SongbasketExTauriWeb.NewBasketLive do
  use SongbasketExTauriWeb, :live_view

  # require SongbasketExTauriWeb
  # SongbasketExTauriWeb.surface_live_component(id: "new-basket")

  alias SongbasketExTauri.{Api, PubSub, Flow, Events, Auth}

  @data [
    {:auth_success, nil},
    {:folder, nil}
  ]

  def mount(_, _, socket) do
    Phoenix.PubSub.subscribe(PubSub, Events.default_topic())
    {:ok, socket |> assign(@data)}
  end

  def handle_event("select_folder", _, socket) do
    {:noreply,
     socket
     |> push_event("dialog", %{
       multiple: false,
       directory: true
     })}
  end

  def handle_event("dialog-answer", [nil, _], socket) do
    {:noreply, socket}
  end

  def handle_event("dialog-answer", [path, _], socket) do
    {:noreply, assign(socket, folder: path)}
  end

  def handle_event("login", _, socket) do
    Auth.start_login_flow()
    {:noreply, socket}
  end

  def handle_event("open_url", %{"url" => url}, socket) do
    Flow.on_open_url(url)

    {:noreply, socket}
  end

  def handle_event("open_url", _, socket) do
    {:noreply, socket}
  end

  def handle_event("current_open_url", _, socket) do
    {:noreply, socket}
  end

  def handle_event("submit", _, socket) do
    %{token: token, spotify_user_id: spotify_id} = socket.assigns.auth_success

    {:ok, basket} =
      Flow.add_basket(%{
        path: socket.assigns.folder,
        user_token: token,
        user_id: spotify_id
      })

    {:noreply, push_navigate(socket, to: ~p"/baskets/#{basket.id}?new=#{true}")}
  end

  def handle_info({:auth_success, response}, socket) do
    dbg(response)

    {:noreply,
     socket
     |> assign(auth_success: response)}
  end

  def render(assigns) do
    ~H"""
    <div class="prose" phx-hook="App" id="new_basket">
      <h1>New basket</h1>
      <p>Select a folder to store your songs.</p>
      <div>
        <button class="btn btn-primary" phx-click="select_folder">
          Select a folder
        </button>
        <b>Selected folder: <%= @folder || "None" %></b>
      </div>
      <div>
        <button class="btn btn-primary" phx-click="login">
          Login to Spotify
        </button>
        <%= if @auth_success do %>
          <b>Logged in: <%= @auth_success.spotify_user_id %></b>
        <% end %>
      </div>

      <%= if @folder && @auth_success do %>
        <button class="btn btn-primary" phx-click="submit">
          Create basket
        </button>
      <% end %>
    </div>
    """
  end
end
