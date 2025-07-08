defmodule Songbasket.Downloader do
  use GenServer
  require Logger
  alias Songbasket.Events
  # TODO handle existing file path
  # TODO link existing tracks if present (by track_id and video_id)
  @spotify_track_tag "songbasket_spotify_id"
  @youtube_video_tag "songbasket_youtube_id"
  @downloads_dir :code.priv_dir(:songbasket) |> Path.join("temp/track_downloads")
  File.mkdir_p!(@downloads_dir)
  @lb ~r/\n|\r/
  @max_concurrency 5

  import Id3vx
  alias Songbasket.Basket

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok,
     %{
       paused: false,
       downloads: %{},
       queue: {[], MapSet.new()}
     }}
  end

  def get_current_downloads do
    GenServer.call(__MODULE__, :get_current_downloads)
  end

  def download_youtube_video({
        video = %Basket.YoutubeVideo{},
        track = %Basket.Track{},
        folder_path
      })
      when is_binary(folder_path) do
    GenServer.cast(__MODULE__, {:queue, {video, track, folder_path}})
  end

  def handle_cast({:queue, item}, state) do
    {:noreply, handle_queue({:enqueue, item}, state)}
  end

  def handle_info(:dequeue, state) do
    {:noreply, handle_queue(:dequeue, state)}
  end

  def handle_queue(:dequeue, %{queue: {[], _}} = state) do
    state
  end

  def handle_queue(:dequeue, %{downloads: downloads, queue: {[item | rest], keys}} = state)
      when map_size(downloads) < @max_concurrency do
    {video, track, _} = item
    key = [track.id, video.id] |> Enum.join(":")

    downloads =
      if not Map.has_key?(downloads, key) do
        task = start_download_async(item)
        payload = download_start_event(track.id, video.id, task.pid)
        Events.emit({:download_progress, payload})

        Map.put(downloads, key, payload)
      else
        Logger.warn("Tried to dequeue a download that was already in progress")
        downloads
      end

    state
    |> Map.put(:downloads, downloads)
    |> Map.put(:queue, {rest, MapSet.delete(keys, key)})
  end

  def handle_queue(:dequeue, %{downloads: downloads} = state)
      when map_size(downloads) >= @max_concurrency do
    Logger.warn("Tried to dequeue when downloads are full")

    state
  end

  def handle_queue({:enqueue, item}, %{downloads: downloads, queue: {queue, keys}} = state) do
    {video, track, _} = item
    key = [track.id, video.id] |> Enum.join(":")

    all_keys =
      MapSet.union(
        keys,
        Map.keys(downloads) |> MapSet.new()
      )

    if MapSet.member?(all_keys, key) do
      Logger.warning("Tried to enque an already enqueued track (#{track.id})")
      state
    else
      send(self(), :dequeue)
      %{state | queue: {queue ++ [item], MapSet.put(keys, key)}}
    end
  end

  def handle_call(:get_current_downloads, _from, state) do
    {:reply, state.downloads, state}
  end

  defp start_download_async(download_item) do
    parent = self()

    Task.Supervisor.async(
      Songbasket.TaskSupervisor,
      fn ->
        start_download(download_item, parent)
      end,
      timeout: :infinity
    )
  end

  defp download_start_event(track_id, video_id, task) do
    %{
      task: task,
      track_id: track_id,
      video_id: video_id,
      status: :starting,
      progress: 0
    }
  end

  def handle_info(
        {:put_progress, track_id, video_id, status, progress},
        state
      ) do
    key = [track_id, video_id] |> Enum.join(":")

    payload =
      Map.get(state.downloads, key)
      |> Map.merge(%{
        status: status,
        progress: progress
      })

    Events.emit({:download_progress, payload})

    {:noreply, %{state | downloads: Map.put(state.downloads, key, payload)}}
  end

  def handle_info({_ref, {:download_complete, track_id, video_id}}, state) do
    key = [track_id, video_id] |> Enum.join(":")

    payload =
      Map.get(state.downloads, key)
      |> Map.merge(%{
        status: :finished,
        progress: 100
      })

    Events.emit({:download_complete, payload})

    send(self(), :dequeue)
    {:noreply, %{state | downloads: Map.delete(state.downloads, key)}}
  end

  def handle_info(ev, state) do
    Logger.warning("Got unknown event @ Downloader: #{inspect(ev)}")
    {:noreply, state}
  end

  defp start_download(
         {
           video = %Basket.YoutubeVideo{},
           track = %Basket.Track{},
           folder_path
         },
         progress_pid
       )
       when is_binary(folder_path) do
    final_path =
      Path.expand(folder_path)
      |> Path.join(track.name <> ".mp3")

    download_path =
      @downloads_dir
      |> Path.join("#{track.id}_#{video.id}" <> ".mp3")

    tags_task = Task.async(fn -> make_tags(video, track) end)

    port = download_youtube_video(video.id, download_path)

    receive_lines = fn receive_lines ->
      receive do
        {^port, {:data, data}} ->
          for line <- String.split(data, @lb, trim: true) do
            case parse_line(line) do
              {:progress, pct, _total, _speed} ->
                send(
                  progress_pid,
                  {:put_progress, track.id, video.id, :downloading, pct}
                )

              :noop ->
                nil

              line ->
                # send(progress_pid, line)
                nil
            end
          end

          receive_lines.(receive_lines)

        {^port, {:exit_status, 0}} ->
          send(
            progress_pid,
            {:put_progress, track.id, video.id, :putting_tags, 100}
          )

          tags = Task.await(tags_task, 60_000)

          :ok = put_tags(tags, download_path, final_path)
          :ok = File.rm(download_path)

          send(
            progress_pid,
            {:put_progress, track.id, video.id, :finished, 100}
          )

          {:download_complete, track.id, video.id}

        {^port, {:exit_status, status}} ->
          {:error, status}
      end
    end

    receive_lines.(receive_lines)
  end

  defp make_tags(video, track) do
    {mime_type, image_data} = get_picture(track.album.images)

    Id3vx.Tag.create(3)
    |> Id3vx.Tag.add_text_frame("TIT1", track.name)
    |> Id3vx.Tag.add_text_frame("TPE1", track.artists |> List.first() |> Map.get(:name))
    |> Id3vx.Tag.add_text_frame("TALB", track.album |> Map.get(:name))
    |> Id3vx.Tag.add_attached_picture("Use Songbasket.com", mime_type, image_data, :cover)
    |> Id3vx.Tag.add_user_defined_text_frame(@spotify_track_tag, track.id)
    |> Id3vx.Tag.add_user_defined_text_frame(@youtube_video_tag, video.id)
  end

  defp get_picture(%{"url" => url}) do
    get_picture(url)
  end

  defp get_picture(url) when is_binary(url) do
    {:ok, {mime_type, binary}} = Songbasket.ExternalResourcesCache.get(url, :binary)
    dbg({url, binary})
    {mime_type, binary}
  end

  defp download_youtube_video(id, path) do
    options = ["extract-audio", "audio-format": "mp3", output: path]
    cmd_params = params("https://www.youtube.com/watch?v=#{id}", options)

    port = Port.open({:spawn, Enum.join(["yt-dlp" | cmd_params], " ")}, [:binary, :exit_status])
  end

  defp put_tags(tag, from_path, to_path) do
    Id3vx.replace_tag(tag, from_path, to_path)
  end

  defp params(url, opts) when is_list(opts) do
    options =
      opts
      |> Enum.reduce([], fn
        {k, v}, acc -> acc ++ ["--#{k}", v]
        arg, acc -> ["--#{arg}" | acc]
      end)

    options ++ [url]
  end

  defp parse_line(<<"[download]", rest::binary>> = line) do
    dbg(line)

    lines =
      rest
      |> String.split(~r/[ ]+/, trim: true)
      |> dbg

    case lines do
      [pct, "of", total, "at", speed | _] ->
        pct = num(pct)
        {:progress, pct, total, speed}

      _ ->
        :noop
    end
  end

  defp parse_line(line) do
    {:line, line}
  end

  defp num(str) do
    {num, _} =
      Regex.run(~r/[\d\.]+/, str)
      |> List.first()
      |> Float.parse()

    num
  end
end
