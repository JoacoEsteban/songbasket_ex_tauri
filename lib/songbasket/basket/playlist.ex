defmodule Songbasket.Basket.Playlist do
  import Songbasket.Map
  alias Songbasket.Basket.{User, Track, PlaylistTrack}
  alias Spotify.{Playlist}

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "playlists" do
    field :name, :string
    belongs_to :owner, User, type: :string, foreign_key: :owner_id, on_replace: :update
    field :description, :string
    field :external_url, :string
    field :images, :map
    field :public, :boolean
    field :collaborative, :boolean
    field :snapshot_id, :string
    field :last_update, :utc_datetime
    # many_to_many :tracks, Track
    has_many :playlist_tracks, PlaylistTrack, foreign_key: :playlist_id
    has_many :tracks, through: [:playlist_tracks, :track]
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(playlist, %Playlist{} = params) do
    params = params |> to_string_map()

    external_url =
      case params["external_urls"] do
        %{"spotify" => url} -> url
      end

    images =
      case params["images"] do
        nil ->
          %{}

        map ->
          map
          |> Enum.sort_by(& &1["height"])
          |> Enum.at(0)
      end

    params =
      params
      |> struct_to_map()
      |> Map.put("external_url", external_url)
      |> Map.put("images", images)
      |> Map.put("owner", User.to_domain(params["owner"]))
      |> IO.inspect(label: :mapped_params)

    changeset(playlist, params)
  end

  def changeset(playlist, params) do
    IO.inspect(params, label: :params)

    required_fields = [
      :id,
      :name,
      :external_url,
      :images,
      :public,
      :collaborative,
      :snapshot_id
    ]

    fields =
      required_fields ++ [:description, :last_update]

    playlist
    |> cast(params, fields)
    |> cast_assoc(:owner)
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
              |> Map.drop([:id, :owner, :last_update])
              |> Map.to_list()
          ]
        }
      })
    end)
  end
end
