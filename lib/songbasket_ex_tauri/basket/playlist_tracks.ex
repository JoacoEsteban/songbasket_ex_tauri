defmodule SongbasketExTauri.Basket.PlaylistTracks do
  use Ecto.Schema
  alias SongbasketExTauri.Basket.{Tracks, Playlists}

  @primary_key false
  schema "playlist_tracks" do
    belongs_to :playlist, Playlists, type: :string, primary_key: true
    belongs_to :track, Tracks, type: :string, primary_key: true
    field :new, :boolean
    field :removed, :boolean
  end
end
