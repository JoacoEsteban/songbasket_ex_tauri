defmodule Songbasket.Repo.Migrations.AddBaskets do
  use Ecto.Migration

  def change do
    create table(:baskets) do
      add :path, :string, null: false, unique: true
      add :user_id, :string, null: false
      add :user_token, :string, null: false

      timestamps()
    end

    create unique_index(:baskets, [:path])

    create table(:config, primary_key: false) do
      add :id, :integer,
        primary_key: true,
        default: 0,
        null: false,
        check: %{name: "single_row", expr: "id = 0"}

      add :selected_basket_id, references(:baskets, on_delete: :nilify_all)
    end
  end
end
