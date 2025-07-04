defmodule SongbasketExTauri.Basket.ArtistTrack do
  use Ecto.Schema
  alias SongbasketExTauri.Basket.{Tracks, Artist}

  @primary_key false
  schema "artist_tracks" do
    belongs_to :artist, Artist, type: :string, primary_key: true
    belongs_to :track, Tracks, type: :string, primary_key: true
  end
end
