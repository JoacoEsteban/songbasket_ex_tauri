defmodule Songbasket.Downloader do
  # TODO handle existing file path
  # TODO link existing tracks if present (by track_id and video_id)
  @spotify_track_tag "songbasket_spotify_id"
  @youtube_video_tag "songbasket_youtube_id"
  @downloads_dir :code.priv_dir(:songbasket) |> Path.join("temp/track_downloads")
  File.mkdir_p!(@downloads_dir)

  import Id3vx
  alias Songbasket.Basket

  def download_youtube_video({
        video = %Basket.YoutubeVideo{},
        track = %Basket.Track{},
        folder_path
      })
      when is_binary(folder_path) do
    final_path =
      Path.expand(folder_path)
      |> Path.join(track.name <> ".mp3")

    download_path =
      @downloads_dir
      |> Path.join("#{track.id}_#{video.id}" <> ".mp3")

    tags = make_tags(video, track)

    {:ok, _} = download_youtube_video(video.id, download_path, tags)

    :ok = put_tags(tags, download_path, final_path)
    :ok = File.rm(download_path)
  end

  def make_tags(video, track) do
    {mime_type, image_data} = get_picture(track.album.images)

    Id3vx.Tag.create(3)
    |> Id3vx.Tag.add_text_frame("TIT1", track.name)
    |> Id3vx.Tag.add_text_frame("TPE1", track.artists |> List.first() |> Map.get(:name))
    |> Id3vx.Tag.add_text_frame("TALB", track.album |> Map.get(:name))
    |> Id3vx.Tag.add_attached_picture("Use Songbasket.com", mime_type, image_data, :cover)
    |> Id3vx.Tag.add_user_defined_text_frame(@spotify_track_tag, track.id)
    |> Id3vx.Tag.add_user_defined_text_frame(@youtube_video_tag, video.id)
  end

  def get_picture(%{"url" => url}) do
    get_picture(url)
  end

  def get_picture(url) when is_binary(url) do
    {:ok, response} =
      Finch.build(:get, url, [], [], [])
      |> Finch.request(Songbasket.Finch)

    %{
      status: 200,
      body: body,
      headers: headers
    } = response

    {_, mime_type} = List.keyfind(headers, "content-type", 0)

    {mime_type, body}
  end

  def download_youtube_video(id, path, tags) do
    options = ["extract-audio", "audio-format": "mp3", output: path]
    Exyt.download("https://www.youtube.com/watch?v=#{id}", options)

    {:ok, path}
  end

  def put_tags(tag, from_path, to_path) do
    Id3vx.replace_tag(tag, from_path, to_path)
  end
end
