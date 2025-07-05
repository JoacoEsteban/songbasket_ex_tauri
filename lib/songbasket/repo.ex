defmodule Songbasket.Repo do
  use Ecto.Repo,
    otp_app: :songbasket,
    adapter: Ecto.Adapters.SQLite3
end
