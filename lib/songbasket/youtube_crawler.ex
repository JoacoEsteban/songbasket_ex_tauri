defmodule Songbasket.YoutubeCrawler do
  @moduledoc false
  require Logger
  @initial_data_prefix_replace "var ytInitialData = "
  @initial_data_prefix @initial_data_prefix_replace <> "{"
  @scraper_cache_dir :code.priv_dir(:songbasket) |> Path.join("cache/scraper")
  File.mkdir_p!(@scraper_cache_dir)

  import Songbasket.Utils

  def search(query) do
    url = "https://www.youtube.com/results?search_query=#{URI.encode(query)}"

    cache_file =
      @scraper_cache_dir
      |> Path.join(URI.encode(query) <> ".html")
      |> Path.expand()

    res =
      case File.read(cache_file) do
        {:ok, _cached} = val ->
          val

        _ ->
          fetch(url)
      end

    case res do
      {:ok, body} ->
        File.write(cache_file, body)
        {:ok, document} = Floki.parse_document(body)

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

  def fetch(url, max_tries \\ 10, tries \\ 0) do
    if tries >= max_tries do
      Logger.error("Max retries exceeded for URL: #{url}")
      {:error, :max_retries_exceeded}
    else
      sleep = tries ** 2 * 500

      Logger.info("Fetching URL: #{url} on try #{tries + 1} of #{max_tries}")

      unless tries == 0, do: Logger.info("Will wait for #{sleep} milliseconds")

      Process.sleep(sleep)

      case Crawly.fetch(url) do
        %{body: body, status_code: 200} ->
          unless tries == 0,
            do: Logger.info("Successfully fetched URL: #{url} after #{tries + 1} tries")

          {:ok, body}

        %{status_code: 302} ->
          fetch(url, max_tries, tries + 1)

        val ->
          dbg(val)
          {:err, val}
      end
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
