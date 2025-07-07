defmodule Songbasket.Tags do
  require Logger
  use Songbasket.Utils

  def retrieve_mp3_file_tags(:dir, path) do
    path = Path.expand(path)
    {:ok, files} = File.ls(path)

    time do
      files
      |> Enum.filter(fn file -> file |> String.ends_with?(".mp3") end)
      |> Task.async_stream(fn file ->
        case retrieve_mp3_file_tags(Path.join(path, file)) do
          {:ok, tags} ->
            {file, tags}

          {:error, err} ->
            Logger.error(err)
            {file, nil}
        end
      end)
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.filter(fn {_, tags} -> tags != nil end)
    end
  end

  def retrieve_mp3_file_tags(path) do
    Id3vx.parse_file(path)
  end
end
