defmodule SongbasketExTauri.Basket.Artist do
  import SongbasketExTauri.Map
  alias SongbasketExTauri.Basket.{User, Artist, Track, Album}
  alias Spotify.{Artist}

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "artists" do
    field :external_url, :string
    field :href, :string
    field :name, :string
    field :uri, :string

    has_many :tracks, Track
    has_many :albums, Album
  end

  @upsert_opts %{
    conflict_target: [:id],
    on_conflict: {:replace_all_except, [:id]}
  }

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(artist, %Artist{} = params) do
    changeset(artist, params |> to_domain())
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
  end

  def changeset(artist, params) do
    required_fields = [
      :id,
      :external_url,
      :href,
      :name,
      :uri
    ]

    fields =
      required_fields ++ []

    artist
    |> cast(params, fields)
    |> validate_required(required_fields)
    |> unique_constraint(:id)
    |> then(fn changeset ->
      changeset
      |> Map.put(:context, %{
        upsert_opts: @upsert_opts
      })
    end)
  end
end
