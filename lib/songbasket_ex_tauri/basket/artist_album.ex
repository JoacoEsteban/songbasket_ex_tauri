defmodule SongbasketExTauri.Basket.ArtistAlbum do
  use Ecto.Schema
  alias SongbasketExTauri.Basket.{Album, Artist}

  @primary_key false
  schema "artist_albums" do
    belongs_to :artist, Artist, type: :string, primary_key: true
    belongs_to :album, Album, type: :string, primary_key: true
  end
end
