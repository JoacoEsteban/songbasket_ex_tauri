defmodule SongbasketExTauri.Flow.BasketRecord do
  @derive {Jason.Encoder,
           only: [
             :path,
             :user_id,
             :user_token
           ]}

  use Ecto.Schema
  import Ecto.Changeset

  schema "baskets" do
    field :path, :string
    field :user_id, :string
    field :user_token, :string

    timestamps()
  end

  def changeset(basket, attrs) do
    basket
    |> cast(attrs, [:path, :user_id, :user_token])
    |> validate_required([:path, :user_id, :user_token])
    |> validate_path_exists()
    |> unique_constraint(:path)
  end

  defp validate_path_exists(changeset) do
    path =
      get_field(changeset, :path)
      |> Path.expand()

    if File.exists?(path) do
      changeset
    else
      add_error(changeset, :path, "does not exist")
    end
  end
end
