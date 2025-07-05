defmodule SongbasketExTauri.Basket.Track do
  import SongbasketExTauri.Map
  alias SongbasketExTauri.Basket.{Users, Albums, Artist, PlaylistTracks, ArtistTrack}
  alias Spotify.Playlist.{Track}

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "tracks" do
    field :name, :string
    field :uri, :string
    belongs_to :album, Albums, type: :string, foreign_key: :album_id, on_replace: :update
    field :duration_ms, :integer
    field :explicit, :boolean
    field :external_ids, :map
    field :preview_url, :string
    has_many :artist_tracks, ArtistTrack
    has_many :artists, through: [:artist_tracks, :artist]
    has_many :playlist_tracks, PlaylistTracks
    has_many :playlists, through: [:playlist_tracks, :playlist]
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(track, %Track{} = params) do
    if params.track.id == "4bqTmTWcoiZXTw7LXVgyFS" do
      dbg(params)
      dbg(params |> to_string_map)
    end

    params =
      params
      |> to_string_map()
      |> Map.get("track")

    # external_url =
    #   case params["external_urls"] do
    #     %{"spotify" => url} -> url
    #   end

    # images =
    #   case params["images"] do
    #     nil ->
    #       %{}

    #     map ->
    #       map
    #       |> Enum.sort_by(& &1["height"])
    #       |> Enum.at(0)
    #   end

    params =
      params
      |> struct_to_map()
      # |> Map.put("external_url", external_url)
      # |> Map.put("images", images)
      |> Map.put("album", Albums.to_domain(params["album"]))
      |> Map.put(
        "artists",
        params["artists"]
        |> Enum.map(&Artist.to_domain/1)
      )

    # |> IO.inspect(label: :mapped_params)

    changeset(track, params)
  end

  def changeset(track, params) do
    # IO.inspect(params, label: :params)

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
    |> cast_assoc(:artists)
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
              |> Map.drop([:id, :album, :artists])
              |> Map.to_list()
          ]
        }
      })
    end)
  end
end
