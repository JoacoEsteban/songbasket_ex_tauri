defmodule SongbasketExTauri.Basket.Migrations.CreateTrackConversions do
  use Ecto.Migration

  def change do
    create table(:track_conversions, primary_key: false) do
      add :spotify_track_id, references(:tracks, type: :string), null: false
      add :youtube_video_id, references(:youtube_videos, type: :string), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:track_conversions, [:spotify_track_id, :youtube_video_id])
  end
end
