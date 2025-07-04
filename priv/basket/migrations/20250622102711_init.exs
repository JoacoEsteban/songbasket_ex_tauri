defmodule SongbasketExTauri.Basket.Migrations.Init do
  use Ecto.Migration

  def change do
    create table(:config, primary_key: false) do
      add :id, :integer,
        primary_key: true,
        default: 0,
        null: false,
        check: %{name: "single_row", expr: "id = 0"}

      add :token, :string, null: true
      add :user_id, references(:users)
    end

    create table(:users, primary_key: false) do
      add :id, :string, primary_key: true
      add :type, :string
      add :product, :string
      add :uri, :string
      add :email, :string
      add :external_url, :string
      add :images, :map
      add :followers, :integer
      add :country, :string
      add :display_name, :string
    end

    create table(:playlists, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :owner_id, references(:users, type: :string), null: false
      add :description, :string, null: true
      add :external_url, :string, null: true
      add :images, :map
      add :public, :boolean
      add :collaborative, :boolean
      add :snapshot_id, :string, null: false
      add :last_update, :date, null: true
    end

    create table(:tracks, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string
      add :uri, :string
      add :album_id, references(:albums, type: :string), null: false
      add :duration_ms, :integer
      add :explicit, :boolean
      add :external_ids, :map
      add :preview_url, :string, null: true
    end

    create table(:albums, primary_key: false) do
      add :id, :string, primary_key: true
      add :album_type, :string
      add :images, :map
      add :external_url, :string
      add :name, :string
      add :release_date, :string
      add :total_tracks, :integer
      add :type, :string
      add :uri, :string
    end

    create table(:artists, primary_key: false) do
      add :id, :string, primary_key: true
      add :external_url, :string
      add :href, :string
      add :name, :string
      add :uri, :string
    end

    create table(:artist_albums, primary_key: false) do
      add :artist_id, references(:artists, type: :string), null: false
      add :album_id, references(:albums, type: :string), null: false
    end

    create table(:artist_tracks, primary_key: false) do
      add :artist_id, references(:artists, type: :string), null: false
      add :track_id, references(:tracks, type: :string), null: false
    end

    create table(:playlist_tracks, primary_key: false) do
      add :playlist_id, references(:playlists, type: :string), null: false
      add :track_id, references(:tracks, type: :string), null: false
      add :new, :boolean, default: true
      add :removed, :boolean, default: false
    end

    create unique_index(:playlist_tracks, [:playlist_id, :track_id])
  end
end
