defmodule SongbasketExTauri.Repo do
  use Ecto.Repo,
    otp_app: :songbasket_ex_tauri,
    adapter: Ecto.Adapters.SQLite3
end
