defmodule SongbasketWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use SongbasketWeb, :controller
      use SongbasketWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: SongbasketWeb.Layouts]

      import Plug.Conn
      import SongbasketWeb.Gettext

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {SongbasketWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import SongbasketWeb.CoreComponents
      alias SongbasketWeb.Components.{Img}
      import SongbasketWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: SongbasketWeb.Endpoint,
        router: SongbasketWeb.Router,
        statics: SongbasketWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  # defmacro __using__([which | opts]) when is_atom(which) and is_list(opts) do
  #   apply(__MODULE__, which, [Keyword.put(opts, :__CALLER__, __CALLER__)])
  # end

  # def surface_live_view do
  #   quote do
  #     use Surface.LiveView,
  #       layout: {SongbasketWeb.Layouts, :app}

  #     unquote(html_helpers())
  #   end
  # end

  # def surface_live_component(opts) when is_list(opts) do
  #   # id = Keyword.fetch!(opts, :id)
  #   id = :crypto.strong_rand_bytes(10) |> Base.encode16(case: :lower)

  #   hook =
  #     to_string(opts[:__CALLER__].module)
  #     |> String.replace_prefix("Elixir.", "")

  #   if id == nil do
  #     raise "Component ID is nil"
  #   end

  #   quote do
  #     Module.put_attribute(__MODULE__, :id, unquote(id))
  #     use Surface.LiveComponent
  #     # use Phoenix.Component

  #     def id, do: unquote(id)

  #     def hook, do: unquote(hook) <> "#default"

  #     def push_event_targeted(socket, event, payload) do
  #       push_event(socket, "relay", %{id: unquote(id), e: event, p: payload})
  #     end

  #     unquote(html_helpers())
  #   end
  # end
end
