defmodule SongbasketExTauri.Basket.YoutubeVideo do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__, as: Video

  @primary_key {:id, :string, autogenerate: false}
  schema "youtube_videos" do
    field :title, :string
    field :duration_text, :string
    field :duration_ms, :integer
    field :thumbnails, {:array, :map}

    timestamps(type: :utc_datetime)
  end

  @upsert_opts %{
    conflict_target: [:id],
    on_conflict: {:replace_all_except, [:id]}
  }

  def upsert_opts, do: @upsert_opts

  def changeset(attrs) do
    Video.changeset(%Video{}, attrs)
  end

  @doc false
  def changeset(youtube_video, attrs) do
    dbg(attrs)

    youtube_video
    |> cast(attrs, [:id, :title, :duration_text, :duration_ms, :thumbnails])
    |> validate_required([:id, :title, :duration_text, :duration_ms, :thumbnails])
    |> then(fn changeset ->
      changeset
      |> Map.put(:context, %{upsert_opts: @upsert_opts})
    end)
  end
end
