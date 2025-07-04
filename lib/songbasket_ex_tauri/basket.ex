defmodule SongbasketExTauri.Basket do
  use Ecto.Repo,
    otp_app: :songbasket_ex_tauri,
    adapter: Ecto.Adapters.SQLite3

  use SongBasketExTauri.DynamicRepoManager, repo_pid_identifier: :basket_repo
  use SongbasketExTauri.RepoHelpers

  require Logger
  alias Spotify.Playlist
  alias SongbasketExTauri.{Basket, Flow, Api, YoutubeCrawler}
  alias SongbasketExTauri.Basket.{Playlists, Tracks, Users, Config, YoutubeVideo, TrackConversion}

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
      inserted_user = Basket.insert!(Users.changeset(user)) |> IO.inspect(label: "Inserted User")
      Basket.insert!(Config.changeset(%{token: token, user_id: inserted_user.id}))
    end)
  end

  def update_playlist_tracks(playlist_id) do
    {:ok, playlists_page, _} = Api.playlist_tracks(id: playlist_id, token: Config.get_token())
    dbg(playlists_page)

    tracks =
      playlists_page.items
      |> Enum.map(fn track ->
        Tracks.changeset(track)
      end)

    albums =
      tracks
      |> Enum.map(& &1.changes.album)
      |> Enum.uniq_by(& &1.changes.id)

    # |> dbg

    Basket.transaction(fn ->
      Enum.each(albums, &Basket.upsert!/1)

      Enum.each(
        tracks
        |> Enum.map(fn track ->
          changes =
            track.changes
            |> Map.put(:album_id, track.changes.album.changes.id)
            |> Map.delete(:album)

          track
          |> Map.put(:changes, changes)
        end),
        fn track ->
          # dbg(track)
          Basket.upsert!(track)

          %Basket.PlaylistTracks{track_id: track.changes.id, playlist_id: playlist_id}
          |> Basket.upsert!(
            on_conflict: :nothing,
            conflict_target: [:playlist_id, :track_id]
          )
        end
      )
    end)
  end

  def update_playlists do
    {:ok, playlists_page, _} = Api.playlists(token: Config.get_token())

    playlists =
      playlists_page.items
      |> Enum.map(fn pl ->
        Playlists.changeset(pl)
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
          |> dbg
        end),
        &Basket.upsert!/1
      )
    end)
  end

  def convert_playlist(playlist_id) do
    playlist =
      Playlists
      |> Basket.get!(playlist_id)
      |> Basket.preload(:tracks)

    tracks =
      playlist
      |> Map.get(:tracks)

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
      max_concurrency: 10
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
    Tracks
    |> Basket.get!(spotify_track_id)
    |> get_track_isrc()
  end

  def get_track_isrc(%Tracks{} = track) do
    track
    |> Map.get(:external_ids)
    |> Map.get("isrc")
  end

  def get_basket do
    # fetch all tables
    %{
      # config: ,
      playlists: Playlists |> Basket.all()
      # playlists: []
    }
  end
end
