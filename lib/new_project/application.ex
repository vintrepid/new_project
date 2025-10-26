defmodule NewProject.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NewProjectWeb.Telemetry,
      NewProject.Repo,
      {DNSCluster, query: Application.get_env(:new_project, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:new_project, :ash_domains),
         Application.fetch_env!(:new_project, Oban)
       )},
      {Phoenix.PubSub, name: NewProject.PubSub},
      # Start a worker by calling: NewProject.Worker.start_link(arg)
      # {NewProject.Worker, arg},
      # Start to serve requests, typically the last entry
      NewProjectWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :new_project]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NewProject.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NewProjectWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
