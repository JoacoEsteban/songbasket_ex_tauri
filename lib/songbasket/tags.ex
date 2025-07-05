defmodule Songbasket.Tags do
  use Songbasket.Utils

  @max_bytes 1024

  @songbasket_tags %{
    "songbasket_spotify_id" => 22,
    "songbasket_youtube_id" => 11
  }

  def retrieve_mp3_file_tags(:dir, path) do
    path = Path.expand(path)
    {:ok, files} = File.ls(path)

    time do
      files
      |> Enum.filter(fn file -> file |> String.ends_with?(".mp3") end)
      |> Task.async_stream(fn file ->
        {file, retrieve_mp3_file_tags(Path.join(path, file))}
      end)
      |> Enum.to_list()
    end
  end

  def retrieve_mp3_file_tags(path) do
    with {:ok, fd} <- :file.open(path, [:read, :binary]),
         {:ok, stats} <- File.stat(path),
         buffer_size <- min(stats.size, @max_bytes),
         {:ok, buffer} <- :file.pread(fd, 0, buffer_size),
         header_pointer <- :binary.match(buffer, <<"TXXX">>),
         true <- header_pointer != :nomatch do
      {start, _len} = header_pointer
      tags_buffer = binary_part(buffer, start, buffer_size - start)

      file_contents =
        tags_buffer
        |> :binary.replace(<<0>>, "", [:global])

      parse_tags(file_contents)
    else
      _ -> []
    end
  end

  defp parse_tags(contents), do: parse_tags(contents, [])

  defp parse_tags(contents, acc) do
    case :binary.match(contents, "songbasket") do
      :nomatch ->
        Enum.reverse(acc)

      {pos, _} ->
        rest =
          binary_part(contents, pos, byte_size(contents) - pos)

        # "ÿþ" in ISO-8859-1
        tag_end =
          :binary.match(rest, <<255, 254>>)

        if tag_end == :nomatch,
          do: Enum.reverse(acc),
          else:
            (
              {tag_end_pos, _} = tag_end
              tag_name = get_tag_name(binary_part(rest, 0, tag_end_pos))
              after_tag = binary_part(rest, tag_end_pos + 2, byte_size(rest) - tag_end_pos - 2)
              tag_length = Map.get(@songbasket_tags, tag_name, 0)
              tag_value = binary_part(after_tag, 0, tag_length)

              next =
                case :binary.match(after_tag, "songbasket") do
                  :nomatch ->
                    ""

                  {next_pos, _} ->
                    binary_part(after_tag, next_pos, byte_size(after_tag) - next_pos)
                end

              if tag_name && tag_value != "" do
                parse_tags(next, [%{name: tag_name, value: tag_value} | acc])
              else
                Enum.reverse(acc)
              end
            )
    end
  end

  defp get_tag_name(name) do
    Enum.find(Map.keys(@songbasket_tags), fn k -> String.starts_with?(name, k) end)
  end

  def print_bin(bin) do
    IO.inspect(bin, binaries: :as_strings)
  end
end
