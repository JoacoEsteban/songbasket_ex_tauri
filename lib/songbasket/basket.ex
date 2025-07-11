defmodule Songbasket.Basket do
  use Ecto.Repo,
    otp_app: :songbasket,
    adapter: Ecto.Adapters.SQLite3

  import Ecto.Query

  use SongBasketExTauri.DynamicRepoManager, repo_pid_identifier: :basket_repo
  use Songbasket.RepoHelpers

  require Logger

  alias Songbasket.Basket.{
    Playlist,
    Track,
    Artist,
    User,
    Config,
    YoutubeVideo,
    TrackConversion
  }

  alias Songbasket.Flow.{
    BasketRecord
  }

  alias Songbasket.{
    Basket,
    Api,
    YoutubeCrawler,
    Downloader,
    Tags,
    Events
  }

  def is_initialized? do
    Basket.aggregate(Config, :count, :id)
    |> IO.inspect(label: :count) > 0
  end

  def maybe_initialize(nil) do
  end

  def maybe_initialize(basket_record) do
    unless is_initialized?() do
      initialize(basket_record.user_token)
      {:ok, nil}
    else
      {:ok, :noop}
    end
  end

  def initialize(token) do
    IO.inspect(token, label: "Token")

    {:ok, user, _} =
      Api.me(token: token)
      |> IO.inspect(label: "User")

    Basket.transaction(fn ->
      inserted_user = Basket.insert!(User.changeset(user)) |> IO.inspect(label: "Inserted User")
      Basket.insert!(Config.changeset(%{token: token, user_id: inserted_user.id}))
    end)
  end

  def update_playlist_tracks(%Playlist{} = playlist) do
    playlist_id = playlist.id

    response =
      if playlist.last_update == nil do
        Api.playlist_first_update(
          id: playlist_id,
          token: Config.get_token()
        )
      else
        Api.playlist_update(
          id: playlist_id,
          snapshot_id: playlist.snapshot_id,
          token: Config.get_token()
        )
      end

    # {:ok, playlists_page, _} = Api.playlist_tracks(id: playlist_id, token: Config.get_token())
    case response do
      {:ok, :not_modified, _} ->
        Logger.info("Playlist #{playlist.name} not modified")

        playlist
        |> Ecto.Changeset.change(%{
          last_update:
            DateTime.utc_now()
            |> DateTime.truncate(:second)
        })
        |> Basket.update()

      {:ok, %{playlist: updated_playlist, tracks: playlists_page}, _} ->
        tracks =
          playlists_page.items
          |> Enum.map(&Track.put_entities/1)

        track_rows =
          playlists_page.items
          |> Enum.map(&Track.changeset/1)

        album_rows =
          track_rows
          |> Enum.map(& &1.changes.album)
          |> Enum.uniq_by(& &1.changes.id)

        artist_rows =
          tracks
          |> Enum.flat_map(fn track ->
            Enum.concat(
              track.artists,
              track.album.artists
            )
          end)
          |> Enum.uniq_by(& &1.id)
          |> Enum.map(&Artist.changeset/1)

        relations =
          [
            {Basket.ArtistTrack, :track_id, tracks},
            {Basket.ArtistAlbum, :album_id,
             tracks |> Enum.uniq_by(& &1.album.id) |> Enum.map(& &1.album)}
          ]
          |> Enum.flat_map(fn {str, key, items} ->
            items
            |> Enum.flat_map(fn item ->
              item
              |> Map.get(:artists)
              |> Enum.map(fn artist ->
                struct(str, [{key, item.id}, {:artist_id, artist.id}])
              end)
            end)
            |> Enum.map(&{&1, [:artist_id, key]})
          end)

        Basket.transaction(fn ->
          Enum.each(artist_rows ++ album_rows, &Basket.upsert!/1)

          Enum.each(track_rows, fn track ->
            playlist_track = %Basket.PlaylistTrack{
              track_id: track.changes.id,
              playlist_id: playlist_id
            }

            track =
              track
              |> Map.put(
                :changes,
                track.changes
                |> Map.put(:album_id, track.changes.album.changes.id)
                |> Map.delete(:album)
              )

            Basket.upsert!(track)

            playlist_track
            |> Basket.upsert!(
              on_conflict: :nothing,
              conflict_target: [:playlist_id, :track_id]
            )
          end)

          Enum.each(relations, fn {relation, target} ->
            relation
            |> Basket.upsert!(
              on_conflict: :nothing,
              conflict_target: target
            )

            updated_playlist =
              updated_playlist
              |> Map.put(
                :last_update,
                DateTime.utc_now() |> DateTime.truncate(:second)
              )

            updated_playlist
            |> dbg

            playlist
            |> Basket.preload(:owner)
            |> Playlist.changeset(updated_playlist)
            |> Basket.update()
          end)
        end)
    end
  end

  def update_playlists do
    {:ok, playlists_page, _} = Api.playlists(token: Config.get_token())

    playlists =
      playlists_page.items
      |> Enum.map(fn pl ->
        Playlist.changeset(pl)
      end)

    owners =
      playlists
      |> Enum.map(& &1.changes.owner)
      |> Enum.uniq_by(& &1.changes.id)

    Basket.transaction(fn ->
      Enum.each(owners, &Basket.upsert!/1)

      Enum.each(
        playlists
        |> Enum.map(fn pl ->
          changes =
            pl.changes
            |> Map.put(:owner_id, pl.changes.owner.changes.id)
            |> Map.put(:last_update, nil)
            |> Map.delete(:owner)

          pl
          |> Map.put(:changes, changes)
        end),
        &Basket.upsert!/1
      )
    end)
  end

  def convert_playlist(playlist_id) when is_binary(playlist_id) do
    convert_playlist(
      Playlist
      |> Basket.get!(playlist_id)
    )
  end

  def convert_playlist(%Playlist{} = playlist) do
    playlist
    |> Basket.preload(tracks: [:conversion])

    tracks =
      playlist
      |> Map.get(:tracks)
      |> Enum.filter(fn track -> track.conversion == nil end)

    results =
      get_playlist_tracks_to_youtube(tracks)
      |> Enum.filter(fn %{track: track, results: results} ->
        case length(results) do
          1 ->
            true

          len ->
            Logger.info(
              [
                "Track '#{track.name}' (id: #{track.id})",
                if len == 0 do
                  "has no results."
                else
                  "has more than 1 result."
                end,
                "Will omit"
              ]
              |> Enum.join(" ")
            )

            false
        end
      end)
      |> Enum.map(fn %{track: track, results: [result]} ->
        {track, result}
      end)

    Basket.transaction(fn ->
      results
      |> Enum.map(fn {_track, result} ->
        result
        |> YoutubeVideo.changeset()
        |> Basket.upsert!()
      end)

      results
      |> Enum.map(fn {track, result} ->
        %TrackConversion{spotify_track_id: track.id, youtube_video_id: result.id}
        |> Basket.upsert!(
          on_conflict: :nothing,
          conflict_target: [:spotify_track_id, :youtube_video_id]
        )
      end)
    end)
  end

  def get_playlist_tracks_to_youtube(tracks) when is_list(tracks) do
    tracks
    |> Task.async_stream(
      fn track ->
        %{
          results: get_youtube_track_results(track),
          track: track,
          isrc: track |> get_track_isrc()
        }
      end,
      max_concurrency: 10,
      timeout: :infinity
    )
    |> Enum.to_list()
    |> Enum.map(fn {:ok, result} -> result end)
  end

  def get_youtube_track_results(spotify_track) do
    get_track_isrc(spotify_track)
    |> case do
      nil -> {:err, :no_isrc}
      isrc -> YoutubeCrawler.search("\"#{isrc}\"")
    end
  end

  def get_track_isrc(spotify_track_id) when is_binary(spotify_track_id) do
    Track
    |> Basket.get!(spotify_track_id)
    |> get_track_isrc()
  end

  def get_track_isrc(%Track{} = track) do
    track
    |> Map.get(:external_ids)
    |> Map.get("isrc")
  end

  def download_playlist(playlist = %Playlist{}, basket = %BasketRecord{}) do
    playlist_path =
      Path.expand(basket.path)
      |> Path.join("playlists")
      |> Path.join(playlist.name)

    :ok = File.mkdir_p(playlist_path)

    existing_tracks =
      Tags.retrieve_mp3_file_tags(:dir, playlist_path)
      |> Enum.map(fn {file, tags} ->
        tags.frames
        |> Enum.filter(fn frame -> frame.id == "TXXX" end)
        |> Enum.map(fn frame -> frame.data end)
        |> Enum.map(fn %{description: k, value: v} -> Map.put(%{}, k, v) end)
        |> Enum.reduce(%{}, &Map.merge/2)
      end)
      |> Enum.reduce(%{}, fn
        %{
          "songbasket_spotify_id" => id,
          "songbasket_youtube_id" => video
        },
        acum ->
          Map.put(acum, id, video)
      end)

    playlist
    |> Basket.preload(tracks: [:album, :artists, conversion: [:youtube_video]])
    |> Map.get(:tracks)
    |> Enum.filter(fn track ->
      track.conversion != nil
    end)
    |> Enum.filter(fn track ->
      conversion_id = track.conversion.youtube_video.id

      case existing_tracks |> Map.get(track.id) do
        nil ->
          true

        video_id ->
          conversion_id != video_id
      end
    end)
    |> Enum.each(fn track ->
      download_track(track, playlist_path)
    end)
  end

  def download_track(%Track{} = track, folder_path) do
    %{conversion: %{youtube_video: video}} =
      track
      |> Basket.preload(conversion: [:youtube_video])

    Downloader.download_youtube_video({video, track, folder_path})

    Logger.info("Download started for track #{track.id}")
  end

  def download_track(track_id, folder_path) when is_binary(track_id) do
    %{spotify_track: track, youtube_video: video} =
      Basket.one(from c in TrackConversion, where: c.spotify_track_id == ^track_id)
      |> Basket.preload(spotify_track: [:album, :artists])
      |> Basket.preload(:youtube_video)

    Downloader.download_youtube_video({video, track, folder_path})
  end

  def get_basket do
    # fetch all tables
    %{
      # config: ,
      playlists: Playlist |> Basket.all()
      # playlists: []
    }
  end
end
