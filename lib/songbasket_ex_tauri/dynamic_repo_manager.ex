defmodule SongBasketExTauri.DynamicRepoManager do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @repo_pid_identifier opts[:repo_pid_identifier]

      def switch_db(db_path) do
        # Stop existing repo if running

        if pid = Process.get(@repo_pid_identifier) do
          Supervisor.stop(pid)
        end

        # Start new repo instance
        {:ok, pid} = start_link(database: db_path, pool_size: 1)

        # Set as active for current process
        put_dynamic_repo(pid)
        Process.put(@repo_pid_identifier, pid)

        :ok
      end

      @doc "Stops current database connection"
      def stop_db do
        if pid = Process.get(@repo_pid_identifier) do
          Supervisor.stop(pid)
          Process.delete(@repo_pid_identifier)
          put_dynamic_repo(nil)
        end

        :ok
      end
    end
  end
end
