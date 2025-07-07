defmodule SongbasketWeb.Router do
  use SongbasketWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SongbasketWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :view do
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SongbasketWeb do
    pipe_through [:browser, :view]

    live_session :app do
      live "/", PageLive
      live "/new_basket", NewBasketLive
      live "/baskets/:id", BasketLive
      live "/baskets/:id/playlists/:playlist_id", BasketPlaylistLive
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:songbasket, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SongbasketWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
