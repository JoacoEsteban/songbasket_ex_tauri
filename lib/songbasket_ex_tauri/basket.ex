defmodule SongbasketExTauri.Basket do
  use Ecto.Repo,
    otp_app: :songbasket_ex_tauri,
    adapter: Ecto.Adapters.SQLite3

  use SongBasketExTauri.DynamicRepoManager, repo_pid_identifier: :basket_repo

  def update_playlists do
    # Implementation goes here
  end
end
