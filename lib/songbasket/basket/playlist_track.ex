defmodule Songbasket.Basket.PlaylistTrack do
  use Ecto.Schema
  alias Songbasket.Basket.{Track, Playlist}

  @primary_key false
  schema "playlist_tracks" do
    belongs_to :playlist, Playlist, type: :string, primary_key: true
    belongs_to :track, Track, type: :string, primary_key: true
    field :new, :boolean
    field :removed, :boolean
  end
end
