defmodule SongbasketWeb.Components.Img do
  use Phoenix.LiveComponent
  alias Songbasket.ExternalResourcesCache, as: Cache

  @data [
    img_result: nil,
    alt: nil
  ]

  def render(assigns) do
    img =
      case assigns.img_result do
        nil -> ""
        {img, _, _} -> img
      end

    ~H"""
    <img src={img} alt={@alt} />
    """
  end

  def mount(socket) do
    socket =
      socket
      |> assign(@data)

    {:ok, socket}
  end

  def update(%{src: src} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> start_async(
        :load_img,
        fn -> Cache.get(src) end
      )

    {:ok, socket}
  end

  def handle_async(:load_img, {:ok, result}, socket) do
    {:noreply, assign(socket, :img_result, result)}
  end

  def handle_async(:load_img, {:exit, reason}, socket) do
    {:noreply, assign(socket, :error, reason)}
  end

  def call(assigns) do
    ~H"""
    <.live_component module={__MODULE__} {assigns} />
    """
  end
end
