defmodule SongBasketExTauri.DynamicRepoManager do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @repo_pid_identifier opts[:repo_pid_identifier]
      @repo_path_identifier Atom.to_string(opts[:repo_pid_identifier]) <> "_path"
      @migrations_path Application.app_dir(:songbasket, "priv/basket/migrations")

      def migrations_path do
        @migrations_path
      end

      def switch_db(db_path, opts \\ [])

      def switch_db(nil, _) do
        stop_db()
      end

      def switch_db(db_path, opts) when is_binary(db_path) do
        db_path = Path.expand(db_path)

        if Process.get(@repo_path_identifier) == db_path do
          :noop
        else
          # Stop existing repo if running
          if pid = Process.get(@repo_pid_identifier) do
            Supervisor.stop(pid)
          end

          IO.inspect(db_path, label: "Starting new repo instance")
          # Start new repo instance
          {:ok, pid} = start_link(database: db_path, pool_size: 1)

          IO.inspect(pid, label: "New repo started")

          # Set as active for current process
          __MODULE__.put_dynamic_repo(pid)
          Process.put(@repo_pid_identifier, pid)
          Process.put(@repo_path_identifier, db_path)

          if opts[:migrate] do
            migrate_repo()
          end

          :ok
        end
      end

      def migrate_repo() do
        pid = Process.get(@repo_pid_identifier)

        case pid do
          nil ->
            {:error, :no_repo_started}

          pid ->
            IO.inspect(pid, label: "Migrating repo")

            Ecto.Migrator.run(__MODULE__, @migrations_path, :up, all: true)
        end
      end

      @doc "Stops current database connection"
      def stop_db do
        if pid = Process.get(@repo_pid_identifier) do
          Supervisor.stop(pid)
          Process.delete(@repo_pid_identifier)
          Process.delete(@repo_path_identifier)
          put_dynamic_repo(nil)
        end

        :ok
      end
    end
  end
end
