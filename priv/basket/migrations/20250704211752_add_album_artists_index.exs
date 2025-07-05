defmodule Songbasket.Basket.Migrations.AddAlbumArtistsIndex do
  use Ecto.Migration

  def change do
    create unique_index(:artist_albums, [:artist_id, :album_id])
    create unique_index(:artist_tracks, [:artist_id, :track_id])
  end
end
