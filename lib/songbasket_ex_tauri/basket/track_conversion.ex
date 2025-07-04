defmodule SongbasketExTauri.Basket.TrackConversion do
  use Ecto.Schema
  import Ecto.Changeset
  alias SongbasketExTauri.Basket.{Tracks, YoutubeVideo}

  @primary_key false
  schema "track_conversions" do
    belongs_to :spotify_track, Tracks, type: :string, primary_key: true
    belongs_to :youtube_video, YoutubeVideo, type: :string, primary_key: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(track_conversion, attrs) do
    track_conversion
    |> cast(attrs, [])
    |> validate_required([])
  end
end
