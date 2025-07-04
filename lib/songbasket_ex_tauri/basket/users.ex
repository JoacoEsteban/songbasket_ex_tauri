defmodule SongbasketExTauri.Basket.Users do
  import SongbasketExTauri.Map
  alias Spotify.{Profile}

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "users" do
    field :type, :string
    field :product, :string
    field :uri, :string
    field :email, :string
    field :external_url, :string
    field :images, :map
    field :followers, :integer
    field :country, :string
    field :display_name, :string
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(user, %Profile{} = params) do
    changeset(user, params |> to_domain())
  end

  def to_domain(params) do
    params = params |> to_string_map()

    external_url =
      case params["external_urls"] do
        %{"spotify" => url} -> url
      end

    followers =
      case params["followers"] do
        %{"total" => total} -> total
        _ -> 0
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

    params
    |> struct_to_map()
    |> Map.put("user_id", params["id"])
    |> Map.put("external_url", external_url)
    |> Map.put("followers", followers)
    |> Map.put("images", images)
    |> IO.inspect(label: :mapped_params)
  end

  def changeset(user, params) do
    required_fields = [
      :id
    ]

    fields =
      required_fields ++
        [
          :external_url,
          :email,
          :type,
          :product,
          :uri,
          :images,
          :followers,
          :country,
          :display_name
        ]

    user
    |> cast(params, fields)
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
              |> Map.drop([:id])
              |> Map.to_list()
          ]
        }
      })
    end)
  end
end
