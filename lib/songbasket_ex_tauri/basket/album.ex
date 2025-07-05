defmodule SongbasketExTauri.Basket.Album do
  import SongbasketExTauri.Basket
  import SongbasketExTauri.Map
  alias SongbasketExTauri.{Basket}
  alias SongbasketExTauri.Basket.{User, Album, Artist}
  alias Spotify.{Album}

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "albums" do
    field :album_type, :string
    field :images, :map
    field :external_url, :string
    field :name, :string
    field :release_date, :string
    field :total_tracks, :integer
    field :type, :string
    field :uri, :string
    has_many :artists, Artist
  end

  def all do
    Basket.all(__MODULE__)
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(album, %Album{} = params) do
    changeset(album, params |> to_domain())
  end

  def to_domain(params) do
    params =
      params
      |> to_string_map()

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
      |> Map.put(
        "artists",
        params["artists"]
        |> Enum.map(&Artist.to_domain/1)
      )

    # |> Map.put("album", Album.to_domain(params["album"]))
    # |> IO.inspect(label: :mapped_params)
  end

  def changeset(album, params) do
    # IO.inspect(params, label: :params)

    required_fields = [
      :id,
      :album_type,
      :images,
      :external_url,
      :name,
      :release_date,
      :total_tracks,
      :type,
      :uri
    ]

    fields =
      required_fields ++ []

    album
    |> cast(params, fields)
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
              |> Map.drop([:id, :artists])
              |> Map.to_list()
          ]
        }
      })
    end)
  end
end
