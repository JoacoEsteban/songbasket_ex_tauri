import Config

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/songbasket_ex_tauri/songbasket_ex_tauri.db
      """

  config :songbasket_ex_tauri, SongbasketExTauri.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
end

# define random port
# port = :rand.uniform(10000)
port = 4000
IO.puts("[config.port]:#{port}")

config :songbasket_ex_tauri, SongbasketExTauriWeb.Endpoint,
  url: [host: "localhost", port: port, scheme: "https"],
  http: [
    port: port
  ],
  secret_key_base: :crypto.strong_rand_bytes(64) |> Base.encode64(),
  server: true
