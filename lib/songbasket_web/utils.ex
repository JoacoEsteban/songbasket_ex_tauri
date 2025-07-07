defmodule SongbasketWeb.Utils do
  import Phoenix.LiveView

  def navigate_basket(socket, path) do
    target_path =
      Path.join(
        "/baskets/",
        basket_id(socket.assigns)
      )
      |> Path.join(path)

    push_navigate(socket, to: target_path)
  end

  def basket_id(%{basket_record: record}) do
    string(record.id)
  end

  def string(int) when is_integer(int) do
    Integer.to_string(int)
  end

  def string(str) when is_binary(str) do
    str
  end
end
