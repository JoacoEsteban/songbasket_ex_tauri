defmodule SongbasketExTauri.RepoHelpers do
  defmacro __using__(_opts) do
    quote do
      def upsert!(changeset) do
        opts =
          changeset.context[:upsert_opts] ||
            raise "Missing :upsert_opts in changeset context"

        upsert!(changeset, opts)
      end

      def upsert!(changeset, opts) do
        __MODULE__.insert!(
          changeset,
          conflict_target: opts[:conflict_target],
          on_conflict: opts[:on_conflict]
        )
      end

      def upsert_all(rows, opts) when is_list(rows) do
        __MODULE__.insert_all(
          rows,
          conflict_target: opts[:conflict_target],
          on_conflict: opts[:on_conflict]
        )
      end
    end
  end
end
