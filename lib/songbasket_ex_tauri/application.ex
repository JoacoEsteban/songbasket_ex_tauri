defmodule SongbasketExTauri.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SongbasketExTauriWeb.Telemetry,
      SongbasketExTauri.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:songbasket_ex_tauri, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster,
       query: Application.get_env(:songbasket_ex_tauri, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SongbasketExTauri.PubSub},
      SongbasketExTauri.BasketManager,
      # Start the Finch HTTP client for sending emails
      {Finch, name: SongbasketExTauri.Finch},
      # Start a worker by calling: SongbasketExTauri.Worker.start_link(arg)
      # {SongbasketExTauri.Worker, arg},
      # Start to serve requests, typically the last entry
      SongbasketExTauriWeb.Endpoint,
      SongbasketExTauri.MemoryStore
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SongbasketExTauri.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SongbasketExTauriWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil
  end
end
