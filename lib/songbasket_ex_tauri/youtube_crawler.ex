defmodule SongbasketExTauri.YoutubeCrawler do
  @moduledoc false
  @initial_data_prefix_replace "var ytInitialData = "
  @initial_data_prefix @initial_data_prefix_replace <> "{"

  import SongbasketExTauri.Utils

  def search(query) do
    url = "https://www.youtube.com/results?search_query=#{URI.encode(query)}"

    cache_file =
      "scrapes"
      |> Path.join(URI.encode(query) <> ".html")
      |> Path.expand()

    res =
      case File.read(cache_file) do
        {:ok, _cached} = val ->
          val

        _ ->
          case Crawly.fetch(url, retries: 3) do
            %{body: body, status_code: 200} ->
              File.write(cache_file, body)
              {:ok, body}

            val ->
              dbg(val)
              {:err, val}
          end
      end

    case res do
      {:ok, body} ->
        {:ok, document} = Floki.parse_document(body)
        # YouTube search results: video links have hrefs starting with "/watch"
        case yt_initial_data(document) do
          nil ->
            dbg(document)
            nil

          {:ok, content} ->
            content
            |> get_mapped_results()
        end

      {:err, _} = val ->
        val
    end
  end

  def get_mapped_results(contents) do
    contents
    |> Map.get("contents")
    |> Map.get("twoColumnSearchResultsRenderer")
    |> Map.get("primaryContents")
    |> Map.get("sectionListRenderer")
    |> Map.get("contents")
    |> Enum.find_value(fn
      %{"itemSectionRenderer" => %{"contents" => c}} -> c
    end)
    |> Enum.map(fn
      %{
        # "lengthText" => %{
        #   "accessibility" => %{
        #     "accessibilityData" => %{"label" => "6 Minuten, 52 Sekunden"}
        #   },
        #   "simpleText" => "6:52"
        #  },

        # "thumbnail" => %{
        #   "thumbnails" => [
        #     %{
        #       "height" => 202,
        #       "url" =>
        #         "https://i.ytimg.com/vi/DlK9396VltU/hq720.jpg?sqp=-oaymwEcCOgCEMoBSFXyq4qpAw4IARUAAIhCGAFwAcABBg==&rs=AOn4CLC1mPYivIbt9adwI4e2EoVVDq3YNA",
        #       "width" => 360
        #     },
        #     %{
        #       "height" => 404,
        #       "url" =>
        #         "https://i.ytimg.com/vi/DlK9396VltU/hq720.jpg?sqp=-oaymwEcCNAFEJQDSFXyq4qpAw4IARUAAIhCGAFwAcABBg==&rs=AOn4CLBdjRkSno6rcQ8XKzgmANilQSzA7w",
        #       "width" => 720
        #     }
        #   ]
        # },

        "videoRenderer" =>
          %{
            "videoId" => id,
            "title" => %{"runs" => [%{"text" => title}]},
            "thumbnail" => %{"thumbnails" => thumbnails},
            "lengthText" => %{
              "simpleText" => durationText
            }
          } = result
      } ->
        # dbg(result)

        %{
          id: id,
          title: String.trim(title),
          thumbnails: thumbnails,
          duration_text: durationText,
          duration_ms: mmss_to_ms(durationText)
        }

      _ ->
        nil
    end)
    |> Enum.filter(fn val -> val != nil end)
  end

  def yt_initial_data(document) do
    script =
      document
      |> Floki.find("script")
      |> Enum.find_value(fn
        {"script", _, [content]} when is_binary(content) ->
          if String.starts_with?(content, @initial_data_prefix) do
            content =
              content
              |> String.trim()
              |> String.replace_prefix(@initial_data_prefix_replace, "")
              |> String.replace_suffix(";", "")

            Jason.decode(content)
          end
      end)

    script
  end
end
