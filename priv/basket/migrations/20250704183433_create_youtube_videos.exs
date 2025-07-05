defmodule Songbasket.Basket.Migrations.CreateYoutubeVideos do
  use Ecto.Migration

  def change do
    create table(:youtube_videos, primary_key: false) do
      add :id, :string, primary_key: true
      add :title, :string
      add :duration_text, :string
      add :duration_ms, :integer
      add :thumbnails, {:array, :map}

      timestamps(type: :utc_datetime)
    end
  end
end
