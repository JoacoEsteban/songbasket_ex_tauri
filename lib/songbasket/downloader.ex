defmodule Songbasket.Downloader do
  import Id3vx
  # download cover image
  # put tags: image, user defined text songbasket_youtube_id, songbasket_isrc, songbasket_spotify_id

  def download_youtube_video({video, track, folder_path}) do
  end

  def download_youtube_video(id, path) do
    options = ["extract-audio", "audio-format": "mp3", output: path]
    Exyt.download("https://www.youtube.com/watch?v=#{id}", options)

    put_tags(path)

    {:ok, path}
  end

  def put_tags(path) do
    # Id3vx.
  end
end
