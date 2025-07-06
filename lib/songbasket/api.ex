defmodule Songbasket.Api do
  alias Songbasket.{Api}
  alias Spotify.{Profile, Playlist, Paging}

  @base_url Application.compile_env!(:songbasket, [Songbasket.Api, :api_url])
  @login_url Path.join(@base_url, "/spotify_login") |> URI.parse()

  def login_url do
    @login_url
  end

  defmodule Page do
    defmacro __using__(item_struct) do
      quote bind_quoted: [item_struct: item_struct] do
        defstruct paging: struct!(Paging), items: []

        def cast(attrs) do
          %__MODULE__{
            paging: struct!(Paging, Map.take(attrs, Paging.__struct__().__schema__(:fields))),
            items: Enum.map(attrs.items, &struct(unquote(item_struct), &1))
          }
        end
      end
    end
  end

  defmodule RequestAuth do
    defstruct [:token, :secret]
  end

  defmodule RetrieveToken do
    defstruct [:token, :spotify_user_id]
  end

  defmodule PlaylistsPage do
    use Page, Playlist
  end

  defmodule Router do
    def build_route(path) do
      {params, parts} = Plug.Router.Utils.build_path_match(path)
      {params, parts}
    end

    def interpolate(parts, opts \\ []) do
      dbg({parts, opts})
      interpolate(parts, [], opts)
    end

    defp interpolate([head | tail], carry_parts, opts) when is_binary(head) do
      interpolate(tail, [head | carry_parts], opts)
    end

    defp interpolate([{param_name, _, _} | tail], carry_parts, opts) when is_atom(param_name) do
      part =
        opts
        |> Keyword.get(param_name)
        |> URI.encode_www_form()

      interpolate(tail, [part | carry_parts], opts)
    end

    defp interpolate([], carry_parts, _opts) do
      carry_parts
      |> Enum.reverse()
      |> Enum.join("/")
    end
  end

  @urls %{
    request_auth: {:get, "/request_auth", RequestAuth, :no_auth},
    retrieve_token: {:get, "/retrieve_token", RetrieveToken, :no_auth},
    me: {:get, "/api/me", Profile, :auth},
    playlists: {:get, "/api/playlists", &Playlist.build_response/1, :auth},
    playlist_tracks: {:get, "/api/playlists/:id/tracks", &Playlist.Track.build_response/1, :auth}
  }

  for {name, {method, path, parser, auth}} <- @urls do
    built_path =
      case(Api.Router.build_route(path)) do
        {[], _} ->
          path

        {_, parts} ->
          {:interpolate, path, parts}
      end

    dbg(built_path)

    def unquote(name)(opts \\ []) do
      headers = opts[:headers] || []
      body = opts[:body] || nil
      token = opts[:token]

      headers =
        case {unquote(auth), token} do
          {:auth, token} when not is_nil(token) ->
            [{"Authorization", "Bearer " <> token} | headers]

          {:no_auth, _} ->
            headers
        end

      interpolated_path =
        unquote(Macro.escape(built_path))
        |> case do
          {:interpolate, path, parts} -> Router.interpolate(parts, opts)
          path -> path
        end
        |> dbg

      final_path = Path.join(@base_url, interpolated_path)

      {:ok, %{status: status} = response} =
        Finch.build(unquote(method), final_path, headers, body, opts)
        |> Finch.request(Songbasket.Finch)

      if status >= 200 && status < 400 do
        response.body

        {:ok, data} =
          Jason.decode(response.body)

        body =
          case unquote(parser) do
            fun when is_function(fun) -> fun.(data)
            mod -> struct(mod, Map.new(data, fn {k, v} -> {String.to_atom(k), v} end))
          end

        {:ok, body, response}
      else
        dbg(response)
        {:error, response.body, response}
      end
    end
  end
end
