defmodule SongbasketExTauri.Events do
  @default_topic "live-view"
  alias SongbasketExTauri.{PubSub}

  def default_topic, do: @default_topic

  def emit(event) do
    emit(event, @default_topic)
  end

  def emit(event, topic) do
    Phoenix.PubSub.broadcast(PubSub, topic, event)
  end
end
