defmodule Songbasket.Basket.Track do
  import Songbasket.Map
  alias Songbasket.Basket.{User, Album, Artist, PlaylistTrack, ArtistTrack, TrackConversion}
  alias Spotify.Playlist.{Track}

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "tracks" do
    field :name, :string
    field :uri, :string
    belongs_to :album, Album, type: :string, foreign_key: :album_id, on_replace: :update
    field :duration_ms, :integer
    field :explicit, :boolean
    field :external_ids, :map
    field :preview_url, :string
    has_many :artist_tracks, ArtistTrack
    has_many :artists, through: [:artist_tracks, :artist]
    has_many :playlist_tracks, PlaylistTrack
    has_many :playlists, through: [:playlist_tracks, :playlist]
    has_one :conversion, TrackConversion, foreign_key: :spotify_track_id
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(track, %Track{} = params) do
    params =
      params
      |> to_string_map()
      |> Map.get("track")

    params =
      params
      |> struct_to_map()
      |> Map.put("album", Album.to_domain(params["album"]))

    changeset(track, params)
  end

  def changeset(track, params) do
    required_fields = [
      :id,
      :name,
      :uri,
      :duration_ms,
      :explicit,
      :external_ids
    ]

    fields =
      required_fields ++ [:preview_url]

    track
    |> cast(params, fields)
    |> cast_assoc(:album)
    |> validate_required(required_fields)
    |> unique_constraint(:id)
    |> then(fn changeset ->
      changeset
      |> Map.put(:context, %{
        upsert_opts: %{
          conflict_target: [:id],
          on_conflict: [
            set:
              changeset.changes
              |> Map.drop([:id, :album])
              |> Map.to_list()
          ]
        }
      })
    end)
  end

  def put_entities(%Spotify.Playlist.Track{} = playlist_track) do
    put_entities(playlist_track.track)
  end

  def put_entities(%Spotify.Track{} = track) do
    track
    |> Artist.put_entity_spotify_artists()
    |> then(fn track ->
      track
      |> Map.put(
        :album,
        Spotify.Helpers.to_struct(Spotify.Album, track.album)
        |> Artist.put_entity_spotify_artists()
      )
    end)
  end
end
